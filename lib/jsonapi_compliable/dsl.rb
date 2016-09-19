module JsonapiCompliable
  class DSL
    attr_accessor :sideloads,
      :default_filters,
      :extra_fields,
      :filters,
      :sorting,
      :pagination

    def initialize
      @sideloads = {}
      @filters = {}
      @default_filters = {}
      @extra_fields = {}
      @sorting = nil
      @pagination = nil
    end

    def includes(whitelist: nil, &blk)
      whitelist = parse_includes(whitelist) if whitelist

      @sideloads = {
        whitelist: whitelist,
        custom_function: blk
      }
    end

    def allow_filter(name, *args, &blk)
      opts = args.extract_options!
      aliases = [name, opts[:aliases]].flatten.compact
      @filters[name.to_sym] = {
        aliases: aliases,
        if: opts[:if],
        filter: blk
      }
    end

    def default_filter(name, &blk)
      @default_filters[name.to_sym] = {
        filter: blk
      }
    end

    def sort(&blk)
      @sorting = blk
    end

    def paginate(&blk)
      @pagination = blk
    end

    def extra_field(field, &blk)
      @extra_fields[field.keys.first] ||= []
      @extra_fields[field.keys.first] << {
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
      @default_filters.each_pair do |name, opts|
        next if find_filter(controller, name)
        scope = opts[:filter].call(scope)
      end

      scope
    end

    private

    def find_filter(controller, name)
      find_filter!(controller, name)
    rescue JSONAPICompliable::Errors::BadFilter
      nil
    end

    def find_filter!(controller, name)
      filter_name, filter_value = \
        @filters.find { |_name, opts| opts[:aliases].include?(name.to_sym) }
      raise JSONAPICompliable::Errors::BadFilter unless filter_name
      if guard = filter_value[:if]
        raise JSONAPICompliable::Errors::BadFilter if controller.send(guard) == false
      end
      { filter_name => filter_value }
    end
  end
end
