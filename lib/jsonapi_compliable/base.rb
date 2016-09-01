module JSONAPICompliable
  class BadFilter < StandardError; end
  class UnsupportedPageSize < StandardError; end

  module Base
    extend ActiveSupport::Concern
    include Deserializable

    MAX_PAGE_SIZE = 1_000

    class JsonApiConfig
      attr_accessor :_includes,
        :_default_filters,
        :_extra_fields,
        :_filters,
        :_sort,
        :_paginate

      def initialize
        @_includes = {}
        @_filters = {}
        @_default_filters = {}
        @_extra_fields = {}
        @_sort = nil
        @_paginate = nil
      end

      def includes(whitelist: nil, &blk)
        whitelist = parse_includes(whitelist) if whitelist

        @_includes = {
          whitelist: whitelist,
          custom_function: blk
        }
      end

      def allow_filter(name, *args, &blk)
        opts = args.extract_options!
        aliases = [name, opts[:aliases]].flatten.compact
        @_filters[name.to_sym] = {
          aliases: aliases,
          if: opts[:if],
          filter: blk
        }
      end

      def default_filter(name, &blk)
        @_default_filters[name.to_sym] = {
          filter: blk
        }
      end

      def sort(&blk)
        @_sort = blk
      end

      def paginate(&blk)
        @_paginate = blk
      end

      def extra_field(field, &blk)
        @_extra_fields[field.keys.first] ||= []
        @_extra_fields[field.keys.first] << {
          name: field.values.first,
          proc: blk
        }
      end

      def parse_includes(includes)
        JSONAPI::IncludeDirective.new(includes)
      end

      def filter_scope(controller, scope, name, value)
        name   = name.to_sym
        filter = find_filter!(controller, name)
        value  = value.split(',') if value.include?(',')

        if custom_scope = filter.values.first[:filter]
          custom_scope.call(scope, value)
        else
          scope.where(filter.keys.first => value)
        end
      end

      def default_filter_scope(controller, scope)
        @_default_filters.each_pair do |name, opts|
          next if find_filter(controller, name)
          scope = opts[:filter].call(scope)
        end

        scope
      end

      private

      def find_filter(controller, name)
        find_filter!(controller, name)
      rescue BadFilter
        nil
      end

      def find_filter!(controller, name)
        filter_name, filter_value = \
          @_filters.find { |_name, opts| opts[:aliases].include?(name.to_sym) }
        raise BadFilter unless filter_name
        if guard = filter_value[:if]
          raise BadFilter if controller.send(guard) == false
        end
        { filter_name => filter_value }
      end
    end

    included do
      class_attribute :_jsonapi_config

      def self.inherited(klass)
        klass._jsonapi_config = nil
      end

      before_action :parse_fieldsets!
    end

    # Private to module
    class CompareIncludes
      def self.call(includes, whitelist)
        {}.tap do |valid|
          includes.to_hash.each_pair do |key, sub_hash|
            if whitelist[key]
              valid[key] = CompareIncludes.call(sub_hash, whitelist[key])
            end
          end
        end
      end
    end

    # Converts include params like foo.bar,baz
    # to AMS-compliant
    # {foo: {bar: {}}, baz: {}}
    #
    # Ensures they are part of the whitelist
    def scrub_includes
      return unless params[:include]

      includes = _jsonapi_config.parse_includes(params[:include])
      whitelist = _jsonapi_config._includes[:whitelist][params[:action]]
      whitelist ? CompareIncludes.call(includes, whitelist) : {}
    end

    def jsonapi_includes(scope)
      scrubbed = scrub_includes
      return scope unless scrubbed

      scope = if custom_include = _jsonapi_config._includes[:custom_function]
                custom_include.call(scope, scrubbed)
              else
                scope.includes(scrubbed)
              end

      scope
    end

    def jsonapi_sort(scope)
      sort_param = params[:sort] || '-id'
      dir = sort_param.starts_with?('-') ? :asc : :desc
      att = sort_param.sub('-', '').to_sym

      scope = if custom_sort = _jsonapi_config._sort
                custom_sort.call(scope, att, dir)
              else
                scope.order(att => dir)
              end

      scope
    end

    def jsonapi_paginate(scope)
      page_param = params[:page] || {}
      number     = (page_param[:number] || default_page_number).to_i
      size       = (page_param[:size]   || default_page_size).to_i

      if size > MAX_PAGE_SIZE
        raise UnsupportedPageSize,"Requested page size #{size} is greater than max supported size #{MAX_PAGE_SIZE}" 
      end

      scope = if custom_pagination = _jsonapi_config._paginate
                custom_pagination.call(scope, number, size)
              else
                scope.page(number).per(size)
              end

      scope
    end

    def jsonapi_filter(scope)
      param_filters = params[:filter] || {}
      scope = _jsonapi_config.default_filter_scope(self, scope)
      param_filters.each_pair do |param_name, param_value|
        scope = _jsonapi_config.filter_scope(self, scope, param_name, param_value)
      end

      scope
    end

    def jsonapi_extra_fields(scope)
      _jsonapi_config._extra_fields.each_pair do |namespace, extra_fields|
        extra_fields.each do |extra_field|
          if requested_extra_field?(namespace, extra_field[:name])
            scope = extra_field[:proc].call(scope)
          end
        end
      end

      scope
    end

    def requested_extra_field?(namespace, field)
      if namespaced = params[:extra_fields].try(:[], namespace)
        namespaced.include?(field)
      else
        false
      end
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
      scope = jsonapi_filter(scope) if filter
      scope = jsonapi_extra_fields(scope) if extra_fields
      scope = jsonapi_includes(scope) if includes
      scope = jsonapi_sort(scope) if sort
      scope = jsonapi_paginate(scope) if paginate
      scope
    end

    def fieldset(name)
      params[name].to_unsafe_hash.deep_symbolize_keys
    end

    def fieldset?(name)
      params[name].present?
    end

    def parse_fieldsets!
      parse_fieldset!(:fields)
      parse_fieldset!(:extra_fields)
    end

    def parse_fieldset!(name)
      return unless params[name]

      params[name].each_pair do |key, value|
        params[name][key] = value.split(',').map(&:to_sym)
      end
    end

    # * Eager loads whitelisted includes
    # * Merges opts and ams_default_options
    def render_ams(scope, opts = {})
      scope = jsonapi_scope(scope) if scope.is_a?(ActiveRecord::Relation)
      options = default_ams_options
      options[:include] = forced_includes || scrub_includes
      options[:json] = scope
      options[:fields] = fieldset(:fields) if fieldset?(:fields)
      options[:extra_fields] = fieldset(:extra_fields) if fieldset?(:extra_fields)

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
        config = JsonApiConfig.new
        config.instance_eval(&blk)
        self._jsonapi_config = config
      end
    end
 end
end
