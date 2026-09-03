module Graphiti
  class Scope
    attr_accessor :object, :unpaginated_object
    attr_reader :pagination

    GLOBAL_THREAD_POOL_EXECUTOR_BROADCAST_STATS = %i[
      length max_length queue_length max_queue completed_task_count largest_length scheduled_task_count synchronous
    ]
    GLOBAL_THREAD_POOL_EXECUTOR = Concurrent::Promises.delay do
      if Graphiti.config.concurrency
        concurrency = Graphiti.config.concurrency_max_threads || 4
        Concurrent::ThreadPoolExecutor.new(
          min_threads: 0,
          max_threads: concurrency,
          max_queue: concurrency * 4,
          fallback_policy: :caller_runs
        )
      else
        Concurrent::ThreadPoolExecutor.new(max_threads: 0, synchronous: true, fallback_policy: :caller_runs)
      end
    end
    private_constant :GLOBAL_THREAD_POOL_EXECUTOR, :GLOBAL_THREAD_POOL_EXECUTOR_BROADCAST_STATS

    def self.global_thread_pool_executor
      GLOBAL_THREAD_POOL_EXECUTOR.value!
    end

    def self.global_thread_pool_stats
      GLOBAL_THREAD_POOL_EXECUTOR_BROADCAST_STATS.each_with_object({}) do |key, memo|
        memo[key] = global_thread_pool_executor.send(key)
      end
    end

    POOL_THREAD = :__graphiti_pool_thread
    private_constant :POOL_THREAD

    # A pool thread that waits on the pool deadlocks, since the task it waits for cannot start until the waiting thread frees its slot.
    def self.resolve_synchronously?
      !Graphiti.config.concurrency || on_pool_thread?
    end

    def self.on_pool_thread?
      Fiber[POOL_THREAD] == true
    end

    # Restores rather than clears because :caller_runs may have run the task on a request thread.
    def self.marking_pool_thread
      previous = Fiber[POOL_THREAD]
      Fiber[POOL_THREAD] = true
      yield
    ensure
      Fiber[POOL_THREAD] = previous
    end

    def initialize(object, resource, query, opts = {})
      @object = object
      @resource = resource
      @query = query
      @opts = opts

      @resolved_sideload_proxies = {}
      @resolved_sideload_proxies_lock = Mutex.new

      @object = @resource.around_scoping(@object, @query.hash) { |scope|
        apply_scoping(scope, opts)
      }
    end

    def resolve(&blk)
      # The caller blocks on .value! either way, so concurrency only benefits parallel sideloads
      # See https://github.com/graphiti-api/graphiti/issues/505
      if self.class.resolve_synchronously? || !overlapping_sideloads?
        sync_resolve(&blk)
      else
        future_resolve(&blk).value!
      end
    end

    def resolve_sideloads(results)
      if self.class.resolve_synchronously?
        sync_resolve_sideloads(results)
      else
        future_resolve_sideloads(results).value!
      end

      # Never return the sideloads hash, a caller mutating it would mess up the cache key
      nil
    end

    def future_resolve(&blk)
      return Concurrent::Promises.fulfilled_future([], self.class.global_thread_pool_executor) if @query.zero_results?

      resolved = resolve_primary_data(&blk)
      sideloaded = @query.parents.any?
      close_adapter = Graphiti.config.concurrency && sideloaded
      if close_adapter
        @resource.adapter.close
      end

      future_resolve_sideloads(resolved)
        .then_on(self.class.global_thread_pool_executor, resolved) { resolved }
    end

    def parent_resource
      @resource
    end

    def cache_key
      # This is the combined cache key for the base query and the query for all sideloads
      # Changing the query will yield a different cache key

      cache_keys = sideload_resource_proxies.map { |proxy| proxy.try(:cache_key) }

      cache_keys << @object.try(:cache_key) # this is what calls into the ORM (ActiveRecord, most likely)
      ActiveSupport::Cache.expand_cache_key(cache_keys.flatten.compact)
    end

    def cache_key_with_version
      # This is the combined and versioned cache key for the base query and the query for all sideloads
      # If any returned model's updated_at changes, this key will change

      cache_keys = sideload_resource_proxies.map { |proxy| proxy.try(:cache_key_with_version) }

      cache_keys << @object.try(:cache_key_with_version) # this is what calls into ORM (ActiveRecord, most likely)
      ActiveSupport::Cache.expand_cache_key(cache_keys.flatten.compact)
    end

    def updated_at
      updated_time = nil
      begin
        updated_ats = sideload_resource_proxies.map(&:updated_at)
        updated_ats << @object.maximum(:updated_at)
        updated_time = updated_ats.compact.max
      rescue => e
        Graphiti.log(["error calculating last_modified_at for #{@resource.class}", :red])
        Graphiti.log(e)
      end

      updated_time || Time.now
    end
    alias_method :last_modified_at, :updated_at

    private

    def sync_resolve(&blk)
      return [] if @query.zero_results?

      resolved = resolve_primary_data(&blk)
      sync_resolve_sideloads(resolved)
      resolved
    end

    def sync_resolve_sideloads(results)
      return if results == []

      collect_foreign_keys(results)
      reset_captured_sideload_proxies
      each_applicable_sideload do |name, sideload, sideload_query|
        Graphiti.config.before_sideload&.call(Graphiti.context)
        sideload.sync_resolve(results, sideload_query, @resource) do |proxy|
          capture_sideload_proxy(name, proxy)
        end
      end
    end

    # Resolve this scope's own data: run hooks, resolve the resource, and
    # decorate the results. Shared by the sync and future paths — everything
    # here runs inline on the calling thread in both modes.
    def resolve_primary_data
      resolved = broadcast_data { |payload|
        @object = @resource.before_resolve(@object, @query)
        payload[:results] = @resource.resolve(@object)
        payload[:results]
      }
      resolved.compact!
      deduplicate_entities!(resolved)
      assign_serializer(resolved)
      yield resolved if block_given?
      @opts[:after_resolve]&.call(resolved)
      @resolved_records = resolved
    end

    # Must run before sideloads assign, so every include path populates the
    # canonical instance. The resource class in the key keeps two resources
    # serving the same model from sharing an instance and a serializer.
    def deduplicate_entities!(resolved)
      return unless deduplicable?

      # Nested maps are built once, a composite key meant a new array for every record
      by_model = @query.entity_map.compute_if_absent(@resource.class) { Concurrent::Map.new }

      resolved.map! do |record|
        next record unless record.respond_to?(:id) && !record.id.nil?

        by_id = by_model.compute_if_absent(record.class) { Concurrent::Map.new }
        by_id.compute_if_absent(record.id) { record }
      end
    end

    # A customized sideload can load a record another path would not, so it keeps its own instances.
    def deduplicable?
      return false unless @query.repeated_resource_classes.include?(@resource.class)

      sideload = @opts[:sideload]
      return true unless sideload

      sideload.scope_proc.nil? &&
        sideload.params_proc.nil? &&
        !sideload.customized_base_scope? &&
        sideload.primary_key == :id
    end

    # One sideload has nothing to run beside it, so the pool would hand the work
    # to another thread and wait for it. A chain is one at every level. A
    # polymorphic sideload counts as its children, which do run beside each other.
    def overlapping_sideloads?
      found = 0
      each_applicable_sideload do |_, sideload, _|
        found += sideload.respond_to?(:children) ? sideload.children.size : 1
        return true if found > 1
      end
      false
    end

    def collect_foreign_keys(results)
      return unless Graphiti.public_ids_declared? && !@opts[:translating_public_ids]

      @resource.class.sideloads.each_value { |sideload| sideload.collect_foreign_keys(results, @query) }
    end

    def each_applicable_sideload
      @query.sideloads.each_pair do |name, sideload_query|
        sideload = @resource.class.sideload(name)
        next if sideload.nil? || sideload.shared_remote?

        yield name, sideload, sideload_query
      end
    end

    # The write path resolves sideloads twice on one scope, which would double every proxy in the cache key.
    def reset_captured_sideload_proxies
      @resolved_sideload_proxies_lock.synchronize { @resolved_sideload_proxies.clear }
    end

    # A proxy built while resolving is already resolved all the way down.
    def capture_sideload_proxy(name, proxy)
      @resolved_sideload_proxies_lock.synchronize do
        captured = (@resolved_sideload_proxies[name] ||= [])
        captured << proxy unless proxy.nil? || proxy == []
      end
    end

    def future_resolve_sideloads(results)
      return Concurrent::Promises.fulfilled_future(nil, self.class.global_thread_pool_executor) if results == []

      collect_foreign_keys(results)
      reset_captured_sideload_proxies
      sideload_promises = []
      each_applicable_sideload do |name, sideload, sideload_query|
        promise = future_with_context(results, sideload_query, @resource) do |parent_results, future_query, parent_resource|
          Graphiti.config.before_sideload&.call(Graphiti.context)
          sideload.future_resolve(parent_results, future_query, parent_resource) do |proxy|
            capture_sideload_proxy(name, proxy)
          end
        end
        sideload_promises << promise.flat
      end

      return sideload_promises.first if sideload_promises.one?

      Concurrent::Promises.zip_futures_on(self.class.global_thread_pool_executor, *sideload_promises)
        .rescue_on(self.class.global_thread_pool_executor) do |*reasons|
          first_error = reasons.find { |r| r.is_a?(Exception) }
          raise first_error
        end
    end

    def future_with_context(*args)
      # TODO: we only need Fiber.storage after Ruby 3.2 is the floor
      thread_storage = Thread.current.keys.each_with_object({}) do |key, memo|
        next if key == POOL_THREAD

        memo[key] = Thread.current[key]
      end
      fiber_storage =
        if Fiber.current.respond_to?(:storage)
          Fiber.current.storage&.keys&.each_with_object({}) do |key, memo|
            memo[key] = Fiber[key]
          end
        end

      current_attributes = current_attributes_snapshot

      Concurrent::Promises.future_on(
        self.class.global_thread_pool_executor, Thread.current.object_id, thread_storage, fiber_storage, current_attributes, *args
      ) do |thread_id, thread_storage, fiber_storage, current_attributes, *args|
        self.class.marking_pool_thread do
          wrap_in_rails_executor do
            with_thread_locals(thread_storage) do
              with_fiber_locals(fiber_storage) do
                with_current_attributes(current_attributes) do
                  with_connection_pool_hint do
                    Graphiti.broadcast(:global_thread_pool_task_run, self.class.global_thread_pool_stats) do
                      yield(*args)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    def current_attributes_snapshot
      return unless defined?(ActiveSupport::CurrentAttributes)

      snapshot = {}
      klasses = ActiveSupport::CurrentAttributes.subclasses
      while (klass = klasses.shift)
        klasses.concat(klass.subclasses)
        attributes = klass.attributes
        snapshot[klass] = attributes.dup if attributes.any?
      end
      snapshot
    end

    # Restored inside the Rails executor, whose entry hands the pool thread a
    # fresh Current. Restoring through set scopes the values to the block.
    def with_current_attributes(snapshot, &block)
      return yield if snapshot.nil? || snapshot.empty?

      klass, attributes = snapshot.first
      rest = snapshot.except(klass)
      klass.set(attributes) { with_current_attributes(rest, &block) }
    end

    # A timeout inside a sideload task nearly always means database.yml's pool
    # was not sized for the sideload threads, and the bare error does not say so.
    def with_connection_pool_hint
      yield
    rescue => error
      raise unless defined?(ActiveRecord::ConnectionTimeoutError) && error.is_a?(ActiveRecord::ConnectionTimeoutError)

      hinted = error.exception(<<~MSG.strip)
        #{error.message}

        Raised while resolving a sideload concurrently. Each concurrent sideload holds its own database connection, so `pool` in database.yml must be at least web threads + concurrency_max_threads (#{Graphiti.config.concurrency_max_threads}) + 1. See graphiti.dev/concepts/resources#concurrency-pool-sizing.
      MSG
      hinted.set_backtrace(error.backtrace)
      raise hinted
    end

    def with_thread_locals(thread_locals)
      new_thread_locals = []
      thread_locals.each do |key, value|
        if !Thread.current[key]
          new_thread_locals << key
        end
        Thread.current[key] = value
      end
      yield
    ensure
      new_thread_locals.each do |key|
        Thread.current[key] = nil
      end
    end

    def with_fiber_locals(fiber_locals)
      return yield unless fiber_locals

      new_fiber_locals = []
      fiber_locals.each do |key, value|
        if !Fiber[key]
          new_fiber_locals << key
        end
        Fiber[key] = value
      end
      yield
    ensure
      new_fiber_locals&.each do |key|
        Fiber[key] = nil
      end
    end

    def wrap_in_rails_executor(&block)
      if defined?(::Rails.application.executor)
        ::Rails.application.executor.wrap(&block)
      else
        yield
      end
    end

    def sideload_resource_proxies
      @sideload_resource_proxies ||= begin
        # Reached after the response resolved, where resolving again re-applies before_resolve to a mutated scope.
        results = @resolved_records
        if results.nil?
          @object = @resource.before_resolve(@object, @query)
          results = @resource.resolve(@object)
        end

        [].tap do |proxies|
          each_applicable_sideload do |name, sideload, q|
            captured = @resolved_sideload_proxies[name]
            if captured
              proxies.concat(captured)
            else
              proxies << sideload.build_resource_proxy(results, q, parent_resource)
            end
          end
        end.flatten
      end
    end

    def broadcast_data
      opts = {
        resource: @resource,
        params: @opts[:params] || @query.params,
        sideload: @opts[:sideload],
        parent: @opts[:parent],
        action: @query.action
        # Set once data is resolved within block
        #   results: ...
      }
      Graphiti.broadcast(:resolve, opts) do |payload|
        yield payload
      end
    end

    # Used to ensure the resource's serializer is used
    # Not one derived through the usual jsonapi-rb logic
    def assign_serializer(records)
      records.each_with_index do |r, index|
        @resource.decorate_record(r, index)
      end
    end

    def apply_scoping(scope, opts)
      @object = scope

      unless @resource.remote?
        opts[:default_paginate] = false unless @query.paginate?
        add_scoping(nil, Graphiti::Scoping::DefaultFilter, opts)
        add_scoping(:filter, Graphiti::Scoping::Filter, opts)
        add_scoping(:sort, Graphiti::Scoping::Sort, opts)
        add_scoping(:paginate, Graphiti::Scoping::Paginate, opts)
      end

      @object
    end

    def add_scoping(key, scoping_class, opts, default = {})
      @object = scoping_class.new(@resource, @query.hash, @object, opts).apply
      @unpaginated_object = @object unless key == :paginate
    end
  end
end
