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

    # TODO: move to Fiber[] once the floor is Ruby 3.2
    def self.on_pool_thread?
      Thread.current[POOL_THREAD] == true
    end

    # Restores rather than clears because :caller_runs may have run the task on a request thread.
    def self.marking_pool_thread
      previous = Thread.current[POOL_THREAD]
      Thread.current[POOL_THREAD] = true
      yield
    ensure
      Thread.current[POOL_THREAD] = previous
    end

    def initialize(object, resource, query, opts = {})
      @object = object
      @resource = resource
      @query = query
      @opts = opts

      @object = @resource.around_scoping(@object, @query.hash) { |scope|
        apply_scoping(scope, opts)
      }
    end

    def resolve(&blk)
      # The caller blocks on .value! either way, so concurrency only benefits parallel sideloads
      # See https://github.com/graphiti-api/graphiti/issues/505
      if self.class.resolve_synchronously? || !applicable_sideloads?
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

    # Synchronous counterpart to #future_resolve, used when concurrency is off.
    # Resolves the resource and its sideloads inline without any promise
    # machinery. See #resolve.
    def sync_resolve(&blk)
      return [] if @query.zero_results?

      resolved = resolve_primary_data(&blk)
      sync_resolve_sideloads(resolved)
      resolved
    end

    # Synchronous counterpart to #future_resolve_sideloads, used when
    # concurrency is off. Resolves each sideload inline. See #resolve_sideloads.
    def sync_resolve_sideloads(results)
      return if results == []

      each_applicable_sideload do |sideload, sideload_query|
        Graphiti.config.before_sideload&.call(Graphiti.context)
        sideload.resolve(results, sideload_query, @resource)
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
      resolved
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
      sideload = @opts[:sideload]
      return true unless sideload

      sideload.scope_proc.nil? &&
        sideload.params_proc.nil? &&
        !sideload.customized_base_scope? &&
        sideload.primary_key == :id
    end

    # Nothing to post to the pool means the future would wrap work already done.
    def applicable_sideloads?
      each_applicable_sideload { return true }
      false
    end

    def each_applicable_sideload
      @query.sideloads.each_pair do |name, sideload_query|
        sideload = @resource.class.sideload(name)
        next if sideload.nil? || sideload.shared_remote?

        yield sideload, sideload_query
      end
    end

    def future_resolve_sideloads(results)
      return Concurrent::Promises.fulfilled_future(nil, self.class.global_thread_pool_executor) if results == []

      sideload_promises = []
      each_applicable_sideload do |sideload, sideload_query|
        promise = future_with_context(results, sideload_query, @resource) do |parent_results, future_query, parent_resource|
          Graphiti.config.before_sideload&.call(Graphiti.context)
          sideload.future_resolve(parent_results, future_query, parent_resource)
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

      Concurrent::Promises.future_on(
        self.class.global_thread_pool_executor, Thread.current.object_id, thread_storage, fiber_storage, *args
      ) do |thread_id, thread_storage, fiber_storage, *args|
        self.class.marking_pool_thread do
          wrap_in_rails_executor do
            with_thread_locals(thread_storage) do
              with_fiber_locals(fiber_storage) do
                Graphiti.broadcast(:global_thread_pool_task_run, self.class.global_thread_pool_stats) do
                  yield(*args)
                end
              end
            end
          end
        end
      end
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
        @object = @resource.before_resolve(@object, @query)
        results = @resource.resolve(@object)

        [].tap do |proxies|
          unless @query.sideloads.empty?
            @query.sideloads.each_pair do |name, q|
              sideload = @resource.class.sideload(name)
              next if sideload.nil? || sideload.shared_remote?

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
