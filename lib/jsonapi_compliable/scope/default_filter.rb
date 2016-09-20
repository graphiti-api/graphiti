module JsonapiCompliable
  class Scope::DefaultFilter < Scope::Base
    include Scope::Filterable

    def apply
      dsl.default_filters.each_pair do |name, opts|
        next if overridden?(name)
        @scope = opts[:filter].call(@scope)
      end

      @scope
    end

    private

    def overridden?(name)
      if found = find_filter(name)
        found_aliases = found[name][:aliases]
        filter_param.keys.any? { |k| found_aliases.include?(k.to_sym) }
      else
        false
      end
    end
  end
end
