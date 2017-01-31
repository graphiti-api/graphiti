# TODO: refactor - code could be better but it's a one-time thing.

module JsonapiCompliable
  class Query
    attr_reader :params, :dsl

    def self.default_hash
      {
        filter: {},
        sort: [],
        page: {},
        include: {},
        extra_fields: [],
        fields: [],
        stats: {}
      }
    end

    def initialize(dsl, params)
      @dsl = dsl
      @params = params
    end

    def to_hash
      hash = { dsl.type => self.class.default_hash }
      dsl.association_names.each do |name|
        hash[name] = self.class.default_hash.except(:include)
      end

      parse_fields(hash, :fields)
      parse_fields(hash, :extra_fields)
      parse_filter(hash)
      parse_sort(hash)
      parse_pagination(hash)
      parse_include(hash)
      parse_stats(hash)

      hash
    end

    # TODO: test
    def fieldsets
      {}.tap do |fs|
        to_hash.each_pair do |namespace, query_hash|
          if query_hash[:fields] and !query_hash[:fields].empty?
            fs[namespace] = query_hash[:fields]
          end
        end
      end
    end

    def zero_results?
      !@params[:page].nil? &&
        !@params[:page][:size].nil? &&
        @params[:page][:size].to_i == 0
    end

    private

    def association?(name)
      dsl.association_names.include?(name)
    end

    # TODO: maybe walk the graph and apply to all
    def parse_include(hash)
      hash[dsl.type][:include] = JSONAPI::IncludeDirective.new(params[:include] || {}).to_hash
    end

    def parse_stats(hash)
      if params[:stats]
        params[:stats].each_pair do |namespace, calculations|
          if namespace == dsl.type || association?(namespace)
            calculations.each_pair do |name, calcs|
              hash[namespace][:stats][name] = calcs.split(',').map(&:to_sym)
            end
          else
            hash[dsl.type][:stats][namespace] = calculations.split(',').map(&:to_sym)
          end
        end
      end
    end

    def parse_fields(hash, type)
      field_params = Util::FieldParams.parse(params[type])
      field_params.each_pair do |namespace, fields|
        hash[namespace][type] = fields
      end
    end

    def parse_filter(hash)
      if filter = params[:filter]
        filter.each_pair do |key, value|
          key = key.to_sym

          if association?(key)
            hash[key][:filter].merge!(value)
          else
            hash[dsl.type][:filter][key] = value
          end
        end
      end
    end

    def parse_sort(hash)
      if sort = params[:sort]
        sorts = sort.split(',')
        sorts.each do |s|
          if s.include?('.')
            type, attr = s.split('.')
            if type.starts_with?('-')
              type = type.sub('-', '')
              attr = "-#{attr}"
            end

            hash[type.to_sym][:sort] << sort_attr(attr)
          else
            hash[dsl.type][:sort] << sort_attr(s)
          end
        end
      end
    end

    def parse_pagination(hash)
      if pagination = params[:page]
        pagination.each_pair do |key, value|
          key = key.to_sym

          if [:number, :size].include?(key)
            hash[dsl.type][:page][key] = value.to_i
          else
            hash[key][:page] = { number: value[:number].to_i, size: value[:size].to_i }
          end
        end
      end
    end

    def sort_attr(attr)
      value = attr.starts_with?('-') ? :desc : :asc
      key   = attr.sub('-', '').to_sym

      { key => value }
    end
  end
end
