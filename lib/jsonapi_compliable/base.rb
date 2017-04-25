module JsonapiCompliable
  module Base
    extend ActiveSupport::Concern

    MAX_PAGE_SIZE = 1_000

    included do
      class << self
        attr_accessor :_jsonapi_compliable
      end

      def self.inherited(klass)
        super
        klass._jsonapi_compliable = Class.new(_jsonapi_compliable)
      end
    end

    def resource
      @resource ||= self.class._jsonapi_compliable.new
    end

    def resource!
      @resource = self.class._jsonapi_compliable.new
    end

    def query
      @query ||= Query.new(resource, params)
    end

    def query_hash
      @query_hash ||= query.to_hash[resource.type]
    end

    def wrap_context
      if self.class._jsonapi_compliable
        resource.with_context(self, action_name.to_sym) do
          yield
        end
      end
    end

    def jsonapi_scope(scope, opts = {})
      resource.build_scope(scope, query, opts)
    end

    def deserialized_params
      @deserialized_params ||= JsonapiCompliable::Deserializer.new(params, request.env)
    end

    def jsonapi_create
      _persist do
        resource.persist_with_relationships \
          deserialized_params.meta,
          deserialized_params.attributes,
          deserialized_params.relationships
      end
    end

    def jsonapi_update
      _persist do
        resource.persist_with_relationships \
          deserialized_params.meta,
          deserialized_params.attributes,
          deserialized_params.relationships
      end
    end

    def _persist
      validation_response = nil
      resource.transaction do
        object = yield
        validation_response = Util::ValidationResponse.new \
          object, deserialized_params
        raise Errors::ValidationError unless validation_response.to_a[1]
      end
      validation_response
    end

    def perform_render_jsonapi(opts)
      JSONAPI::Serializable::Renderer.render(opts.delete(:jsonapi), opts)
    end

    def render_jsonapi(scope, opts = {})
      scope = jsonapi_scope(scope) unless opts[:scope] == false || scope.is_a?(JsonapiCompliable::Scope)
      opts  = default_jsonapi_render_options.merge(opts)
      opts  = Util::RenderOptions.generate(scope, query_hash, opts)
      opts[:expose][:context] = self
      opts[:include] = deserialized_params.include_directive if force_includes?
      perform_render_jsonapi(opts)
    end

    # render_jsonapi(foo) equivalent to
    # render jsonapi: foo, default_jsonapi_render_options
    def default_jsonapi_render_options
      {}.tap do |options|
      end
    end

    def force_includes?
      not params[:data].nil?
    end

    module ClassMethods
      def jsonapi(resource: nil, &blk)
        if resource
          self._jsonapi_compliable = resource
        else
          if !self._jsonapi_compliable
            self._jsonapi_compliable = Class.new(JsonapiCompliable::Resource)
          end
        end

        self._jsonapi_compliable.class_eval(&blk) if blk
      end
    end
  end
end
