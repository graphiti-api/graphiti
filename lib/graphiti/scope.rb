module Graphiti
  class Scope
    attr_accessor :object, :unpaginated_object
    attr_reader :pagination
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
      if @query.zero_results?
        []
      else
        resolved = broadcast_data { |payload|
          @object = @resource.before_resolve(@object, @query)
          payload[:results] = @resource.resolve(@object)
          payload[:results]
        }
        resolved.compact!
        assign_serializer(resolved)
        yield resolved if block_given?
        @opts[:after_resolve]&.call(resolved)
        resolve_sideloads(resolved) unless @query.sideloads.empty?
        resolved
      end
    end

    def resolve_sideloads(results)
      return if results == []

      concurrent = Graphiti.config.concurrency
      promises = []

      @query.sideloads.each_pair do |name, q|
        sideload = @resource.class.sideload(name)
        next if sideload.nil? || sideload.shared_remote?
        parent_resource = @resource
        graphiti_context = Graphiti.context
        resolve_sideload = -> {
          Graphiti.config.before_sideload&.call(graphiti_context)
          Graphiti.context = graphiti_context
          sideload.resolve(results, q, parent_resource)
          @resource.adapter.close if concurrent
        }
        if concurrent
          promises << Concurrent::Promise.execute(&resolve_sideload)
        else
          resolve_sideload.call
        end
      end

      if concurrent
        # Wait for all promises to finish
        sleep 0.01 until promises.all? { |p| p.fulfilled? || p.rejected? }
        # Re-raise the error with correct stacktrace
        # OPTION** to avoid failing here?? if so need serializable patch
        # to avoid loading data when association not loaded
        if (rejected = promises.find(&:rejected?))
          raise rejected.reason
        end
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
      rescue => e
        Graphiti.log(["error calculating last_modified_at for #{@resource.class}", :red])
        Graphiti.log(e)
      end

      updated_time || Time.now
    end
    alias_method :last_modified_at, :updated_at

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
