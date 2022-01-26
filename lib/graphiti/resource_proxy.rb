module Graphiti
  class ResourceProxy
    include Enumerable

    attr_reader :resource, :query, :scope, :payload

    def initialize(resource, scope, query,
      payload: nil,
      single: false,
      raise_on_missing: false)
      @resource = resource
      @scope = scope
      @query = query
      @payload = payload
      @single = single
      @raise_on_missing = raise_on_missing
    end

    def single?
      !!@single
    end

    def raise_on_missing?
      !!@raise_on_missing
    end

    def errors
      data.errors
    end

    def [](val)
      data[val]
    end

    def jsonapi_render_options(opts = {})
      opts[:expose] ||= {}
      opts[:expose][:context] = Graphiti.context[:object]
      opts
    end

    def to_jsonapi(options = {})
      options = jsonapi_render_options(options)
      Renderer.new(self, options).to_jsonapi
    end

    def to_json(options = {})
      Renderer.new(self, options).to_json
    end

    def as_json(options = {})
      Renderer.new(self, options).as_json
    end

    def to_xml(options = {})
      Renderer.new(self, options).to_xml
    end

    def to_graphql(options = {})
      Renderer.new(self, options).to_graphql
    end

    def as_graphql(options = {})
      Renderer.new(self, options).as_graphql
    end

    def data
      @data ||= begin
        records = @scope.resolve
        if records.empty? && raise_on_missing?
          raise Graphiti::Errors::RecordNotFound
        end
        records = records[0] if single?
        records
      end
    end
    alias_method :to_a, :data

    def meta
      @meta ||= data.respond_to?(:meta) ? data.meta : {}
    end

    def each(&blk)
      to_a.each(&blk)
    end

    def stats
      @stats ||= if @query.hash[:stats]
        payload = Stats::Payload.new @resource,
          @query,
          @scope.unpaginated_object,
          data
        payload.generate
      else
        {}
      end
    end

    def pagination
      @pagination ||= Delegates::Pagination.new(self)
    end

    def save(action: :create)
      # TODO: remove this. Only used for persisting many-to-many with AR
      # (see activerecord adapter)
      original = Graphiti.context[:namespace]
      begin
        Graphiti.context[:namespace] = action
        ::Graphiti::RequestValidator.new(@resource, @payload.params, action).validate!
        validator = persist {
          @resource.persist_with_relationships \
            @payload.meta(action: action),
            @payload.attributes,
            @payload.relationships
        }
      ensure
        Graphiti.context[:namespace] = original
      end
      @data, success = validator.to_a

      if success
        # If the context namespace is `update` or `create`, certain
        # adapters will cause N+1 validation calls, so lets explicitly
        # switch to a lookup context.
        Graphiti.with_context(Graphiti.context[:object], :show) do
          @scope.resolve_sideloads([@data])
        end
      end

      success
    end

    def destroy
      data
      transaction_response = @resource.transaction do
        metadata = {method: :destroy}
        model = @resource.destroy(@query.filters[:id], metadata)
        model.instance_variable_set(:@__serializer_klass, @resource.serializer)
        @resource.after_graph_persist(model, metadata)
        validator = ::Graphiti::Util::ValidationResponse.new \
          model, @payload
        validator.validate!
        @resource.before_commit(model, metadata)

        {result: validator}
      end
      @data, success = transaction_response[:result].to_a
      success
    end

    def update_attributes
      data
      save(action: :update)
    end

    def include_hash
      @include_hash ||= begin
        base = @payload ? @payload.include_hash : {}
        base.deep_merge(@query.include_hash)
      end
    end

    def fields
      query.fields
    end

    def extra_fields
      query.extra_fields
    end

    def debug_requested?
      query.debug_requested?
    end

    private

    def persist
      transaction_response = @resource.transaction do
        ::Graphiti::Util::TransactionHooksRecorder.record do
          model = yield
          ::Graphiti::Util::TransactionHooksRecorder.run_graph_persist_hooks
          validator = ::Graphiti::Util::ValidationResponse.new \
            model, @payload
          validator.validate!
          validator
        end
      end

      _data, success = transaction_response[:result].to_a
      if success
        transaction_response[:after_commit_hooks].each do |hook|
          hook.call
        end
      end

      transaction_response[:result]
    end
  end
end
