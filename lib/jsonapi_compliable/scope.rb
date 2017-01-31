module JsonapiCompliable
  class Scope
    def initialize(object, dsl, query, opts = {})
      @object  = object
      @dsl     = dsl
      @query   = query

      apply_scoping(opts)
    end

    def resolve_stats
      Stats::Payload.new(@dsl, query_hash, @unpaginated_object).generate
    end

    def resolve
      if @query.zero_results?
        []
      else
        @object
      end
    end

    def query_hash
      @query_hash ||= @query.to_hash[@dsl.type]
    end

    private

    def apply_scoping(opts)
      @object = JsonapiCompliable::Scoping::DefaultFilter.new(@dsl, query_hash, @object).apply
      @object = JsonapiCompliable::Scoping::Filter.new(@dsl, query_hash, @object).apply unless opts[:filter] == false
      @object = JsonapiCompliable::Scoping::ExtraFields.new(@dsl, query_hash, @object).apply unless opts[:extra_fields] == false
      @object = JsonapiCompliable::Scoping::Sideload.new(@dsl, query_hash, @object).apply unless opts[:includes] == false
      @object = JsonapiCompliable::Scoping::Sort.new(@dsl, query_hash, @object).apply unless opts[:sort] == false
      @unpaginated_object = @object
      @object = JsonapiCompliable::Scoping::Paginate.new(@dsl, query_hash, @object).apply unless opts[:paginate] == false
    end
  end
end
