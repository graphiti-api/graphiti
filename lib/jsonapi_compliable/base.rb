module JsonapiCompliable
  module Base
    extend ActiveSupport::Concern
    include Deserializable

    MAX_PAGE_SIZE = 1_000

    included do
      class_attribute :_jsonapi_compliable
      attr_reader :_jsonapi_scope

      around_action :wrap_context
    end

    # TODO pass controller and action name here to guard
    def wrap_context
      _jsonapi_compliable.with_context(self, action_name.to_sym) do
        yield
      end
    end

    def jsonapi_scope(scope, opts = {})
      query = Query.new(_jsonapi_compliable, params)
      _jsonapi_compliable.build_scope(scope, query, opts)
    end

    # TODO: refactor
    def render_jsonapi(scope, opts = {})
      query = Query.new(_jsonapi_compliable, params)
      query_hash = query.to_hash[_jsonapi_compliable.type]

      scoped = scope
      scoped = jsonapi_scope(scoped) unless opts[:scope] == false || scoped.is_a?(JsonapiCompliable::Scope)
      resolved = scoped.respond_to?(:resolve) ? scoped.resolve : scoped

      options = default_jsonapi_render_options
      options[:include] = forced_includes || Util::IncludeParams.scrub(query_hash[:include], _jsonapi_compliable.allowed_sideloads)
      options[:jsonapi] = resolved
      options[:fields] = query.fieldsets
      options[:meta] ||= {}
      options.merge!(opts)

      if scoped.respond_to?(:resolve_stats)
        stats = scoped.resolve_stats
        options[:meta][:stats] = stats unless stats.empty?
      end

      options[:expose] ||= {}
      options[:expose][:context] = self
      options[:expose][:extra_fields] = query_hash[:extra_fields]

      render(options)
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
      return unless force_includes?
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
      def jsonapi(&blk)
        if !self._jsonapi_compliable
          dsl = JsonapiCompliable::DSL.new
          self._jsonapi_compliable = dsl
        else
          self._jsonapi_compliable = self._jsonapi_compliable.copy
        end

        self._jsonapi_compliable.instance_eval(&blk)
      end
    end
  end
end
