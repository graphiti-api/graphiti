module Graphiti
  # Default filters apply to every request, unless specifically overridden in
  # the request.
  #
  # Maybe we only want to show active posts:
  #
  #   class PostResource < ApplicationResource
  #     # ... code ...
  #     default_filter :active do |scope|
  #       scope.where(active: true)
  #     end
  #   end
  #
  # But if the user is an admin and specifically requests inactive posts:
  #
  #   class PostResource < ApplicationResource
  #     # ... code ...
  #     allow_filter :active, if: admin?
  #
  #     default_filter :active do |scope|
  #       scope.where(active: true)
  #     end
  #   end
  #
  #   # Now a GET /posts?filter[active]=false will return inactive posts
  #   # if the user is an admin.
  #
  # @see Resource.default_filter
  # @see Resource.allow_filter
  class Scoping::DefaultFilter < Scoping::Base
    include Scoping::Filterable

    # Apply the default filtering logic.
    # Loop through each defined default filter, and apply the default
    # proc unless an explicit override is requested
    #
    # @return scope the scope object we are chaining/modifying
    def apply
      resource.default_filters.each_pair do |name, opts|
        next if overridden?(name)
        @scope = resource.instance_exec(@scope, resource.context, &opts[:filter])
      end

      @scope
    end

    private

    def overridden?(name)
      if (found = find_filter(name))
        found_aliases = found[name][:aliases]
        filter_param.keys.any? { |k| found_aliases.include?(k.to_sym) }
      else
        false
      end
    end
  end
end
