module JsonapiCompliable
  class DSL
    attr_accessor :sideloads,
      :default_filters,
      :extra_fields,
      :filters,
      :sorting,
      :stats,
      :pagination

    def initialize
      clear!
    end

    def copy
      instance = self.class.new
      instance.sideloads = sideloads.deep_dup
      instance.filters = filters.deep_dup
      instance.default_filters = default_filters.deep_dup
      instance.extra_fields = extra_fields.deep_dup
      instance.sorting = sorting.deep_dup
      instance.pagination = pagination.deep_dup
      instance.stats = stats.deep_dup
      instance
    end

    def clear!
      @sideloads = {}
      @filters = {}
      @default_filters = {}
      @extra_fields = {}
      @stats = {}
      @sorting = nil
      @pagination = nil
    end

    def includes(whitelist: nil, &blk)
      whitelist = JSONAPI::IncludeDirective.new(whitelist) if whitelist

      @sideloads = {
        whitelist: whitelist,
        custom_scope: blk
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

    def allow_stat(symbol_or_hash, &blk)
      dsl = Stats::DSL.new(symbol_or_hash)
      dsl.instance_eval(&blk) if blk
      @stats[dsl.name] = dsl
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

    def stat(attribute, calculation)
      stats_dsl = @stats[attribute] || @stats[attribute.to_sym]
      raise Errors::StatNotFound.new(attribute, calculation) unless stats_dsl
      stats_dsl.calculation(calculation)
    end
  end
end
