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
          Graphiti.context = graphiti_context
          sideload.resolve(results, q, parent_resource)
          if concurrent && defined?(ActiveRecord)
            ActiveRecord::Base.clear_active_connections!
          end
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

    private

    def broadcast_data
      opts = {
        resource: @resource,
        params: @opts[:params],
        sideload: @opts[:sideload],
        parent: @opts[:parent]
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
      records.each do |r|
        @resource.decorate_record(r)
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
