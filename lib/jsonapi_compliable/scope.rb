module JsonapiCompliable
  class Scope
    attr_accessor :object, :unpaginated_object

    def initialize(object, resource, query, opts = {})
      @object    = object
      @resource  = resource
      @query     = query
      @opts      = opts

      @object = @resource.around_scoping(@object, query_hash) do |scope|
        apply_scoping(scope, opts)
      end
    end

    def resolve_stats
      if query_hash[:stats]
        Stats::Payload.new(@resource, @query, @unpaginated_object).generate
      else
        {}
      end
    end

    def resolve
      if @query.zero_results?
        []
      else
        resolved = @resource.resolve(@object)
        assign_serializer(resolved)
        yield resolved if block_given?
        if @opts[:after_resolve]
          @opts[:after_resolve].call(resolved)
        end
        sideload(resolved) unless @query.sideloads.empty?
        resolved
      end
    end

    def query_hash
      @query_hash ||= @query.to_hash
    end

    private

    # Used to ensure the resource's serializer is used
    # Not one derived through the usual jsonapi-rb logic
    def assign_serializer(records)
      records.each do |r|
        serializer = @resource.serializer_for(r)
        r.instance_variable_set(:@__serializer_klass, serializer)
      end
    end

    def sideload(results)
      return if results == []

      concurrent = ::JsonapiCompliable.config.experimental_concurrency
      promises = []

      @query.sideloads.each_pair do |name, q|
        sideload = @resource.class.sideload(name)
        resolve_sideload = -> { sideload.resolve(results, q) }
        if concurrent
          promises << Concurrent::Promise.execute(&resolve_sideload)
        else
          resolve_sideload.call
        end
      end

      if concurrent
        # Wait for all promises to finish
        while !promises.all? { |p| p.fulfilled? || p.rejected? }
          sleep 0.01
        end
        # Re-raise the error with correct stacktrace
        # OPTION** to avoid failing here?? if so need serializable patch
        # to avoid loading data when association not loaded
        if rejected = promises.find(&:rejected?)
          raise rejected.reason
        end
      end
    end

    def apply_scoping(scope, opts)
      @object = scope
      add_scoping(nil, JsonapiCompliable::Scoping::DefaultFilter, opts)
      add_scoping(:filter, JsonapiCompliable::Scoping::Filter, opts)
      add_scoping(:sort, JsonapiCompliable::Scoping::Sort, opts)
      add_scoping(:paginate, JsonapiCompliable::Scoping::Paginate, opts)
      @object
    end

    def add_scoping(key, scoping_class, opts, default = {})
      @object = scoping_class.new(@resource, query_hash, @object, opts).apply
      @unpaginated_object = @object unless key == :paginate
    end
  end
end
