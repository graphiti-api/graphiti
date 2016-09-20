module JsonapiCompliable
  module Base
    extend ActiveSupport::Concern
    include Deserializable

    MAX_PAGE_SIZE = 1_000

    included do
      class_attribute :_jsonapi_compliable
      before_action :parse_fieldsets!
      after_action :reset_scope_flag
    end

    def default_page_number
      1
    end

    def default_page_size
      20
    end

    def jsonapi_scope(scope,
                      filter: true,
                      includes: true,
                      paginate: true,
                      extra_fields: true,
                      sort: true)
      scope = JsonapiCompliable::Scope::DefaultFilter.new(self, scope).apply
      scope = JsonapiCompliable::Scope::Filter.new(self, scope).apply if filter
      scope = JsonapiCompliable::Scope::ExtraFields.new(self, scope).apply if extra_fields
      scope = JsonapiCompliable::Scope::Sideload.new(self, scope).apply if includes
      scope = JsonapiCompliable::Scope::Sort.new(self, scope).apply if sort
      scope = JsonapiCompliable::Scope::Paginate.new(self, scope).apply if paginate
      @_jsonapi_scoped = true
      scope
    end

    def reset_scope_flag
      @_jsonapi_scoped = false
    end

    def parse_fieldsets!
      Util::FieldParams.parse!(params, :fields)
      Util::FieldParams.parse!(params, :extra_fields)
    end

    def render_ams(scope, opts = {})
      opts[:scope] = true unless opts[:scope] == false
      scope = jsonapi_scope(scope) if !@_jsonapi_scoped && opts.delete(:scope)
      options = default_ams_options
      options[:include] = forced_includes || Util::IncludeParams.scrub(self)
      options[:json] = scope
      options[:fields] = Util::FieldParams.fieldset(params, :fields) if params[:fields]
      options[:extra_fields] = Util::FieldParams.fieldset(params, :extra_fields) if params[:extra_fields]

      options.merge!(opts)
      render(options)
    end

    # render_ams(foo) equivalent to
    # render json: foo, ams_default_options
    def default_ams_options
      {}.tap do |options|
        options[:adapter] = :json_api
      end
    end

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

    def force_includes?
      %w(PUT PATCH POST).include?(request.method) and
        raw_params[:data][:relationships].present?
    end

    module ClassMethods
      def jsonapi(&blk)
        if !self._jsonapi_compliable
          dsl = JsonapiCompliable::DSL.new
          self._jsonapi_compliable = dsl
        end
        self._jsonapi_compliable.instance_eval(&blk)
      end
    end
  end
end
