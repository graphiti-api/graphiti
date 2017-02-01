module JsonapiCompliable
  class Scope
    def initialize(object, resource, query, opts = {})
      @object    = object
      @resource  = resource
      @query     = query

      # Namespace for the 'outer' or 'main' resource is its type
      # For its relationships, its the relationship name
      # IOW when hitting /states, it's resource type 'states
      # when hitting /authors?include=state its 'state'
      @namespace = opts.delete(:namespace) || resource.type

      apply_scoping(opts)
    end

    def resolve_stats
      Stats::Payload.new(@resource, query_hash, @unpaginated_object).generate
    end

    def resolve
      if @query.zero_results?
        []
      else
        resolved = @object
        # TODO - configurable resolve function
        resolved = @object.to_a if @object.is_a?(ActiveRecord::Relation)
        sideload(resolved, query_hash[:include]) if query_hash[:include]
        resolved
      end
    end

    def query_hash
      @query_hash ||= @query.to_hash[@namespace]
    end

    private

    def sideload(results, includes)
      includes.each_pair do |name, nested|
        if @resource.allowed_sideloads.has_key?(name)
          sideload         = @resource.sideload(name)
          sideload_scope   = sideload.scope_proc.call(results)
          sideload_scope   = Scope.new(sideload_scope, sideload.resource, @query, namespace: sideload.name)
          sideload_results = sideload_scope.resolve
          sideload.assign_proc.call(results, sideload_results)
        end
      end
    end

    def apply_scoping(opts)
      @object = JsonapiCompliable::Scoping::DefaultFilter.new(@resource, query_hash, @object).apply
      @object = JsonapiCompliable::Scoping::Filter.new(@resource, query_hash, @object).apply unless opts[:filter] == false
      @object = JsonapiCompliable::Scoping::ExtraFields.new(@resource, query_hash, @object).apply unless opts[:extra_fields] == false
      @object = JsonapiCompliable::Scoping::Sort.new(@resource, query_hash, @object).apply unless opts[:sort] == false
      @unpaginated_object = @object
      @object = JsonapiCompliable::Scoping::Paginate.new(@resource, query_hash, @object).apply unless opts[:paginate] == false
    end
  end
end
