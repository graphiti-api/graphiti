module JsonapiCompliable
  class Query
    attr_reader :resource, :include_hash

    def initialize(resource, params, association_name = nil, nested_include = nil)
      @resource = resource
      @association_name = association_name
      @params = params
      @params = @params.permit! if @params.respond_to?(:permit!)
      @params = @params.to_h if @params.respond_to?(:to_h)
      @params = @params.deep_symbolize_keys
      @include_param = nested_include || @params[:include]
    end

    def association?
      !!@association_name
    end

    def top_level?
      not association?
    end

    def to_hash
      {}.tap do |hash|
        hash[:filter] = filters unless filters.empty?
        hash[:sort] = sorts unless sorts.empty?
        hash[:page] = pagination unless pagination.empty?
        unless association?
          hash[:fields] = fields unless fields.empty?
          hash[:extra_fields] = extra_fields unless extra_fields.empty?
        end
        hash[:stats] = stats unless stats.empty?
        hash[:include] = sideload_hash unless sideload_hash.empty?
      end
    end

    def zero_results?
      !@params[:page].nil? &&
        !@params[:page][:size].nil? &&
        @params[:page][:size].to_i == 0
    end

    def sideload_hash
      @sideload_hash = begin
        {}.tap do |hash|
          sideloads.each_pair do |key, value|
            hash[key] = sideloads[key].to_hash
          end
        end
      end
    end

    def sideloads
      @sideloads ||= begin
        {}.tap do |hash|
          include_hash.each_pair do |key, sub_hash|
            sideload = @resource.class.sideload(key)
            if sideload
              hash[key] = Query.new(sideload.resource, @params, key, sub_hash)
            else
              handle_missing_sideload(key)
            end
          end
        end
      end
    end

    def fields
      @fields ||= begin
        hash = parse_fieldset(@params[:fields] || {})
        hash.each_pair do |type, fields|
          hash[type] += extra_fields[type] if extra_fields[type]
        end
        hash
      end
    end

    def extra_fields
      @extra_fields ||= parse_fieldset(@params[:extra_fields] || {})
    end

    def filters
      @filters ||= begin
        {}.tap do |hash|
          (@params[:filter] || {}).each_pair do |name, value|
            name = name.to_sym

            if legacy_nested?(name)
              filter_name = value.keys.first.to_sym
              filter_value = value.values.first
              if @resource.get_attr!(filter_name, :filterable, request: true)
                hash[filter_name] = filter_value
              end
            elsif top_level? && validate!(name, :filterable)
              hash[name] = value
            end
          end
        end
      end
    end

    def sorts
      @sorts ||= begin
        return @params[:sort] if @params[:sort].is_a?(Array)
        return [] if @params[:sort].nil?

        [].tap do |arr|
          sort_hashes do |key, value, type|
            if legacy_nested?(type)
              @resource.get_attr!(key, :sortable, request: true)
              arr << { key => value }
            elsif !type && top_level? && validate!(key, :sortable)
              arr << { key => value }
            end
          end
        end
      end
    end

    def pagination
      @pagination ||= begin
        {}.tap do |hash|
          (@params[:page] || {}).each_pair do |name, value|
            if legacy_nested?(name)
              value.each_pair do |k,v|
                hash[k.to_sym] = v.to_i
              end
            elsif top_level? && [:number, :size].include?(name.to_sym)
              hash[name.to_sym] = value.to_i
            end
          end
        end
      end
    end

    def include_hash
      @include_hash ||= begin
        requested = include_directive.to_hash

        whitelist = nil
        if @resource.context
          whitelist = @resource.context._sideload_whitelist
          whitelist = whitelist[@resource.context_namespace] if whitelist
        end

        whitelist ? Util::IncludeParams.scrub(requested, whitelist) : requested
      end
    end

    def stats
      @stats ||= begin
        {}.tap do |hash|
          (@params[:stats] || {}).each_pair do |k, v|
            if legacy_nested?(k)
              raise NotImplementedError.new('Association statistics are not currently supported')
            elsif top_level?
              v = v.split(',') if v.is_a?(String)
              hash[k.to_sym] = Array(v).flatten.map(&:to_sym)
            end
          end
        end
      end
    end

    private

    def validate!(name, flag)
      not_associated_name = !@resource.class.association_names.include?(name)
      not_associated_type = !@resource.class.association_types.include?(name)
      if not_associated_name && not_associated_type
        @resource.get_attr!(name, flag, request: true)
        return true
      end
      false
    end

    def legacy_nested?(name)
      association? &&
        (name == @resource.type || name == @association_name)
    end

    def parse_fieldset(fieldset)
      {}.tap do |hash|
        fieldset.each_pair do |type, fields|
          type       = type.to_sym
          fields     = fields.split(',') unless fields.is_a?(Array)
          hash[type] = fields.map(&:to_sym)
        end
      end
    end

    def include_directive
      @include_directive ||= JSONAPI::IncludeDirective.new(@include_param)
    end

    def handle_missing_sideload(name)
      if JsonapiCompliable.config.raise_on_missing_sideload
        raise JsonapiCompliable::Errors::InvalidInclude
          .new(name, @resource.type)
      end
    end

    def sort_hash(attr)
      value = attr[0] == '-' ? :desc : :asc
      key   = attr.sub('-', '').to_sym

      { key => value }
    end

    def sort_hashes
      sorts = @params[:sort].split(',')
      sorts.each do |s|
        type, attr = s.split('.')

        if attr.nil? # top-level
          next if @association_name
          hash = sort_hash(type)
          yield hash.keys.first.to_sym, hash.values.first
        else
          if type[0] == '-'
            type = type.sub('-', '')
            attr = "-#{attr}"
          end
          hash = sort_hash(attr)
          yield hash.keys.first.to_sym, hash.values.first, type.to_sym
        end
      end
    end
  end
end
