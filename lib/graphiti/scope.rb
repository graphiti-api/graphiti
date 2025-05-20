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

    def initialize(object, resource, query, opts = {})
      @object = object
      @resource = resource
      @query = query
      @opts = opts

      @object = @resource.around_scoping(@object, @query.hash) { |scope|
        apply_scoping(scope, opts)
      }
    end

    def resolve
      future_resolve.value!
    end

    def resolve_sideloads(results)
      future_resolve_sideloads(results).value!
    end

    def future_resolve
      return Concurrent::Promises.fulfilled_future([], self.class.global_thread_pool_executor) if @query.zero_results?

      resolved = broadcast_data { |payload|
        @object = @resource.before_resolve(@object, @query)
        payload[:results] = @resource.resolve(@object)
        payload[:results]
      }
      resolved.compact!
      assign_serializer(resolved)
      yield resolved if block_given?
      @opts[:after_resolve]&.call(resolved)
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

    def future_resolve_sideloads(results)
      return Concurrent::Promises.fulfilled_future(nil, self.class.global_thread_pool_executor) if results == []

      sideload_promises = @query.sideloads.filter_map do |name, q|
        sideload = @resource.class.sideload(name)
        next if sideload.nil? || sideload.shared_remote?

        p = future_with_context(results, q, @resource) do |parent_results, sideload_query, parent_resource|
          Graphiti.config.before_sideload&.call(Graphiti.context)
          sideload.future_resolve(parent_results, sideload_query, parent_resource)
        end
        p.flat
      end

      Concurrent::Promises.zip_futures_on(self.class.global_thread_pool_executor, *sideload_promises)
        .rescue_on(self.class.global_thread_pool_executor) do |*reasons|
          first_error = reasons.find { |r| r.is_a?(Exception) }
          raise first_error
        end
    end

    def future_with_context(*args)
      thread_storage = Thread.current.keys.each_with_object({}) do |key, memo|
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
