module Graphiti
  class ResourceProxy
    include Enumerable

    attr_reader :resource, :query, :scope, :payload, :cache_expires_in, :cache, :cache_tag

    def initialize(
      resource,
      scope,
      query,
      payload: nil,
      single: false,
      raise_on_missing: false,
      assign_action: nil,
      cache: nil,
      cache_expires_in: nil,
      cache_tag: nil
    )

      @resource = resource
      @scope = scope
      @query = query
      @payload = payload
      @single = single
      @raise_on_missing = raise_on_missing
      @assign_action = assign_action
      @cache = cache
      @cache_expires_in = cache_expires_in
      @cache_tag = cache_tag
    end

    def cache?
      !!@cache
    end

    alias_method :cached?, :cache?

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
      return @data unless @data.nil?
      return assign_attributes(@payload.params) if @assign_action

      @data = begin
        records = @scope.resolve
        raise Graphiti::Errors::RecordNotFound if records.empty? && raise_on_missing?

        records = records[0] if single?
        records
      end
    end

    alias_method :to_a, :data
    alias_method :resolve_data, :data

    def future_resolve_data
      @scope.future_resolve.then do |records|
        raise Graphiti::Errors::RecordNotFound if records.empty? && raise_on_missing?

        records = records[0] if single?
        @data = records
      end
    end

    def meta
      @meta ||= data.respond_to?(:meta) ? data.meta : {}
    end

    def each(&blk)
      to_a.each(&blk)
    end

    def stats
      @stats ||= if @query.hash[:stats]
        scope = @scope.unpaginated_object
        if resource.adapter.can_group?
          if (group = @query.hash[:stats].delete(:group_by))
            scope = resource.adapter.group(scope, group[0])
          end
        end
        payload = Stats::Payload.new @resource,
          @query,
          scope,
          data
        payload.generate
      else
        {}
      end
    end

    def pagination
      @pagination ||= Delegates::Pagination.new(self)
    end

    # Apply request params to the underlying model without saving it,
    # Rails-style: the params are always passed explicitly, in the same
    # request-params shape find/build accept. They are validated,
    # deserialized, and become the payload #save will persist.
    #
    # Idempotent per params - calling again with params that normalize to
    # the same payload is a no-op, so the attributes callbacks fire once.
    # Different params re-assign onto the same model instance.
    #
    # Note the attributes callbacks fire here, outside any transaction
    # opened during #save - the persistence hooks wrap only the save phase,
    # receiving this assigned model.
    def assign_attributes(params)
      action = @assign_action || :update
      params = normalized_params_copy(params)
      add_endpoint_filter(params, action)
      validator = ::Graphiti::RequestValidator.new(@resource, params, action)
      validator.validate!

      if @assigned_model && same_write_payload?(validator.deserialized_payload)
        return @assigned_model
      end

      @payload = validator.deserialized_payload
      @assigned_model = @data = @resource.assign_with_relationships(
        @payload.meta(action: action),
        @payload.attributes,
        @payload.relationships,
        model_instance: @assigned_model || (data if action == :update)
      )
    end

    def save(action: :create)
      # TODO: remove this. Only used for persisting many-to-many with AR
      # (see activerecord adapter)
      original = Graphiti.context[:namespace]
      begin
        Graphiti.context[:namespace] = action
        # An assigned model can only come from #assign_attributes, which
        # validated the payload it stored - re-validating here would run the
        # writable guards (and their guard_model lookups) a redundant time.
        unless @assigned_model
          ::Graphiti::RequestValidator.new(@resource, @payload.params, action).validate!
        end
        validator = persist {
          @resource.persist_with_relationships \
            @payload.meta(action: action),
            @payload.attributes,
            @payload.relationships,
            assigned_model: @assigned_model
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
      resolve_data
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

    # Rails-style: pass params to assign and save in one call, or call with
    # no arguments to save a payload assigned earlier (via find or
    # #assign_attributes).
    def update(params = nil)
      assign_attributes(params) if params
      resolve_data
      save(action: :update)
    end

    alias_method :update_attributes, :update

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

    def updated_at
      @scope.updated_at
    end

    def etag
      "W/#{ActiveSupport::Digest.hexdigest(cache_key_with_version.to_s)}"
    end

    def resource_cache_tag
      return unless @cache_tag.present? && @resource.respond_to?(@cache_tag)

      @resource.try(@cache_tag)
    end

    def cache_key
      ActiveSupport::Cache.expand_cache_key(
        [
          @scope.cache_key,
          @query.cache_key,
          resource_cache_tag
        ].compact_blank
      )
    end

    def cache_key_with_version
      ActiveSupport::Cache.expand_cache_key(
        [
          @scope.cache_key_with_version,
          @query.cache_key,
          resource_cache_tag
        ].compact_blank
      )
    end

    private

    # Validation typecasts values and injects ids into the params it is
    # given - work on a deep copy so the caller's hash stays untouched.
    def normalized_params_copy(params)
      if params.respond_to?(:to_unsafe_h)
        params.to_unsafe_h.deep_symbolize_keys
      else
        ::Graphiti::Util::Hash.deep_dup(params)
      end
    end

    # UpdateValidator enforces that data.id matches the endpoint's filter id.
    # Params that came through find already carry that filter; params passed
    # directly to #assign_attributes usually don't, so merge in the id this
    # proxy was found with. A payload whose data.id names a different record
    # still fails validation with ConflictRequest. Mutates the copy made by
    # #normalized_params_copy, never caller state.
    def add_endpoint_filter(params, action)
      return unless action == :update

      endpoint_id = @query.filters[:id]
      return if endpoint_id.nil? || params[:filter].try(:[], :id)

      params[:filter] ||= {}
      params[:filter][:id] = endpoint_id
    end

    # Compare only the write payload (data + included) - a repeat call whose
    # params differ in read-side keys like sort or page is still a no-op.
    def same_write_payload?(deserialized_payload)
      deserialized_payload.params.values_at(:data, :included) ==
        @payload.params.values_at(:data, :included)
    end

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
