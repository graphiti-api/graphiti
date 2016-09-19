module JSONAPICompliable
  class Scope::DefaultFilter < Scope::Base
    include Scope::Filterable

    def apply
      dsl.default_filters.each_pair do |name, opts|
        next if find_filter(name)
        @scope = opts[:filter].call(@scope)
      end

      @scope
    end
  end
end
