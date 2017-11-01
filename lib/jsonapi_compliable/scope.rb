module JsonapiCompliable
  # A Scope wraps an underlying object. It modifies that object
  # using the corresponding Resource and Query, and how to resolve
  # that underlying object scope.
  #
  # @example Basic Controller usage
  #   def index
  #     base  = Post.all
  #     scope = jsonapi_scope(base)
  #     scope.object == base # => true
  #     scope.object = scope.object.where(active: true)
  #
  #     # actually fires sql
  #     scope.resolve #=> [#<Post ...>, #<Post ...>, etc]
  #   end
  class Scope
    # @param object - The underlying, chainable base scope object
    # @param resource - The Resource that will process the object
    # @param query - The Query object for the current request
    # @param [Hash] opts Options to configure the Scope
    # @option opts [String] :namespace The nested relationship name
    # @option opts [Boolean] :filter Opt-out of filter scoping
    # @option opts [Boolean] :extra_fields Opt-out of extra_fields scoping
    # @option opts [Boolean] :sort Opt-out of sort scoping
    # @option opts [Boolean] :pagination Opt-out of pagination scoping
    # @option opts [Boolean] :default_paginate Opt-out of default pagination when not specified in request
    def initialize(object, resource, query, opts = {})
      @object    = object
      @resource  = resource
      @query     = query

      # Namespace for the 'outer' or 'main' resource is its type
      # For its relationships, its the relationship name
      # IOW when hitting /states, it's resource type 'states'
      # when hitting /authors?include=state its 'state'
      @namespace = opts.delete(:namespace) || resource.type

      apply_scoping(opts)
    end

    # Resolve the requested stats. Returns hash like:
    #
    #   { rating: { average: 5.5, maximum: 9 } }
    #
    # @return [Hash] the resolved stat info
    # @api private
    def resolve_stats
      Stats::Payload.new(@resource, query_hash, @unpaginated_object).generate
    end

    # Resolve the scope. This is where SQL is actually fired, an HTTP
    # request is actually made, etc.
    #
    # Does nothing if the user requested zero results, ie /posts?page[size]=0
    #
    # First resolves the top-level resource, then processes each relevant sideload
    #
    # @see Resource#resolve
    # @return [Array] an array of resolved model instances
    def resolve
      if @query.zero_results?
        []
      else
        resolved = @resource.resolve(@object)
        sideload(resolved, query_hash[:include]) if query_hash[:include]
        resolved
      end
    end

    # The slice of Query#to_hash for the current namespace
    # @see Query#to_hash
    # @api private
    def query_hash
      @query_hash ||= @query.to_hash[@namespace]
    end

    private

    def sideload(results, includes)
      return if results == []

      includes.each_pair do |name, nested|
        sideload = @resource.sideload(name)

        unless sideload
          raise JsonapiCompliable::Errors::InvalidInclude.new(name, @resource.type)
        end

        namespace = Util::Sideload.namespace(@namespace, sideload.name)
        sideload.resolve(results, @query, namespace)
      end
    end

    def apply_scoping(opts)
      @object = JsonapiCompliable::Scoping::DefaultFilter.new(@resource, query_hash, @object).apply
      @object = JsonapiCompliable::Scoping::Filter.new(@resource, query_hash, @object).apply unless opts[:filter] == false
      @object = JsonapiCompliable::Scoping::ExtraFields.new(@resource, query_hash, @object).apply unless opts[:extra_fields] == false
      @object = JsonapiCompliable::Scoping::Sort.new(@resource, query_hash, @object).apply unless opts[:sort] == false
      @unpaginated_object = @object
      @object = JsonapiCompliable::Scoping::Paginate.new(@resource, query_hash, @object, default: opts[:default_paginate]).apply unless opts[:paginate] == false
    end
  end
end
