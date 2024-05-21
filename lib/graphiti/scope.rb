module Graphiti
  class Scope
    attr_accessor :object, :unpaginated_object
    attr_reader :pagination

    # TODO: this could be a Concurrent::Promises.delay
    GLOBAL_THREAD_POOL_EXECUTOR = Concurrent::Delay.new do
      # concurrency = Graphiti.config.concurrency_max_threads || 4
      Concurrent::ThreadPoolExecutor.new(max_threads: 0, synchronous: true, fallback_policy: :caller_runs)
    end
    private_constant :GLOBAL_THREAD_POOL_EXECUTOR

    def self.global_thread_pool_executor
      GLOBAL_THREAD_POOL_EXECUTOR.value!
    end

    def initialize(object, resource, query, opts = {})
      @object = object
      @resource = resource
      @query = query
      @opts = opts

      @object = @resource.around_scoping(@object, @query.hash) do |scope|
        apply_scoping(scope, opts)
      end
    end

    def resolve
      if @query.zero_results?
        []
      else
        resolved = broadcast_data do |payload|
          @object = @resource.before_resolve(@object, @query)
          payload[:results] = @resource.resolve(@object)
          payload[:results]
        end
        resolved.compact!
        assign_serializer(resolved)
        yield resolved if block_given?
        @opts[:after_resolve]&.call(resolved)
        sideloads_result = @query.sideloads.empty? ? nil : resolve_sideloads(resolved)
        if sideloads_result.is_a?(Concurrent::Promises::Future)
          sideloads_result
        else
          resolved
        end
      end
    end

    def resolve_sideloads(results)
      return if results == []

      concurrent = Graphiti.config.concurrency

      promises = @query.sideloads.filter_map do |name, q|
        sideload = @resource.class.sideload(name)
        next if sideload.nil? || sideload.shared_remote?

        parent_resource = @resource
        graphiti_context = Graphiti.context

        p = Concurrent::Promises.future_on(self.class.global_thread_pool_executor) do
          Graphiti.config.before_sideload&.call(graphiti_context)
          Graphiti.context = graphiti_context
          results = sideload.resolve(results, q, parent_resource)
          @resource.adapter.close if concurrent
          if results.is_a?(Concurrent::Promises::Future)
            results
          else
            Concurrent::Promises.fulfilled_future(results, self.class.global_thread_pool_executor)
          end
        end

        if q.sideloads.any?
          p.flat
        else
          p
        end
      end

      p = Concurrent::Promises.zip_futures_on(self.class.global_thread_pool_executor, *promises)
      if @query.parents.empty?
        p.value!
      else
        p
      end
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
      rescue StandardError => e
        Graphiti.log(["error calculating last_modified_at for #{@resource.class}", :red])
        Graphiti.log(e)
      end

      updated_time || Time.now
    end
    alias last_modified_at updated_at

    private

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

    def broadcast_data(&block)
      opts = {
        resource: @resource,
        params: @opts[:params] || @query.params,
        sideload: @opts[:sideload],
        parent: @opts[:parent],
        action: @query.action
        # Set once data is resolved within block
        #   results: ...
      }
      Graphiti.broadcast(:resolve, opts, &block)
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

    def add_scoping(key, scoping_class, opts, _default = {})
      @object = scoping_class.new(@resource, @query.hash, @object, opts).apply
      @unpaginated_object = @object unless key == :paginate
    end
  end
end
