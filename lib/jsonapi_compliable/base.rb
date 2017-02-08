module JsonapiCompliable
  module Base
    extend ActiveSupport::Concern
    include Deserializable

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

    # TODO pass controller and action name here to guard
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

    def perform_render_jsonapi(opts)
      JSONAPI::Serializable::Renderer.render(opts.delete(:jsonapi), opts)
    end

    def render_jsonapi(scope, opts = {})
      scope = jsonapi_scope(scope) unless opts[:scope] == false || scope.is_a?(JsonapiCompliable::Scope)
      opts  = default_jsonapi_render_options.merge(opts)
      opts  = Util::RenderOptions.generate(scope, query_hash, opts)
      opts[:expose][:context] = self
      opts[:include] = forced_includes if force_includes?
      perform_render_jsonapi(opts)
    end

    # render_jsonapi(foo) equivalent to
    # render jsonapi: foo, default_jsonapi_render_options
    def default_jsonapi_render_options
      {}.tap do |options|
      end
    end

    # Legacy
    # TODO: This nastiness likely goes away once jsonapi standardizes
    # a spec for nested relationships.
    # See: https://github.com/json-api/json-api/issues/1089
    def forced_includes(data = nil)
      data = raw_params[:data] unless data

      {}.tap do |forced|
        (data[:relationships] || {}).each_pair do |relation_name, relation|
          if relation[:data].is_a?(Array)
            forced[relation_name] = {}
            relation[:data].each do |datum|
              forced[relation_name].deep_merge!(forced_includes(datum))
            end
          else
            forced[relation_name] = forced_includes(relation[:data])
          end
        end
      end
    end

    # Legacy
    def force_includes?
      %w(PUT PATCH POST).include?(request.method) and
        raw_params.try(:[], :data).try(:[], :relationships).present?
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
