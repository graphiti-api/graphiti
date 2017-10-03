module JsonapiCompliable
   # @attr_reader [Hash] params hash of query parameters with symbolized keys
   # @attr_reader [Resource] resource the corresponding Resource object
  class Query
    # TODO: This class could use some refactoring love!
    attr_reader :params, :resource

    # This is the structure of +Query#to_hash+ used elsewhere in the library
    # @see #to_hash
    # @api private
    # @return [Hash] the default hash
    def self.default_hash
      {
        filter: {},
        sort: [],
        page: {},
        include: {},
        stats: {},
        fields: {},
        extra_fields: {}
      }
    end

    def initialize(resource, params)
      @resource = resource
      @params = params
      @params = @params.permit! if @params.respond_to?(:permit!)
    end

    # The relevant include directive
    # @see http://jsonapi-rb.org
    # @return [JSONAPI::IncludeDirective]
    def include_directive
      @include_directive ||= JSONAPI::IncludeDirective.new(params[:include])
    end

    # The include, directive, as a hash. For instance
    #
    # { posts: { comments: {} } }
    #
    # This will only include relationships that are
    #
    # * Available on the Resource
    # * Whitelisted (when specified)
    #
    # So that users can't simply request your entire object graph.
    #
    # @see Util::IncludeParams
    # @return [Hash] the scrubbed include directive as a hash
    def include_hash
      @include_hash ||= begin
        requested = include_directive.to_hash

        whitelist = nil
        if resource.context
          whitelist = resource.context.sideload_whitelist
          whitelist = whitelist[resource.context_namespace] if whitelist
        end

        whitelist ? Util::IncludeParams.scrub(requested, whitelist) : requested
      end
    end

    # All the keys of the #include_hash
    #
    # For example, let's say we had
    #
    #   { posts: { comments: {} }
    #
    # +#association_names+ would return
    #
    #   [:posts, :comments]
    #
    # @return [Array<Symbol>] all association names, recursive
    def association_names
      @association_names ||= Util::Hash.keys(include_hash)
    end

    # A flat hash of sanitized query parameters.
    # All relationship names are top-level:
    #
    #   {
    #     posts: { filter, sort, ... }
    #     comments: { filter, sort, ... }
    #   }
    #
    # @example sorting
    #   # GET /posts?sort=-title
    #   { posts: { sort: { title: :desc } } }
    #
    # @example pagination
    #   # GET /posts?page[number]=2&page[size]=10
    #   { posts: { page: { number: 2, size: 10 } }
    #
    # @example filtering
    #   # GET /posts?filter[title]=Foo
    #   { posts: { filter: { title: 'Foo' } }
    #
    # @example include
    #   # GET /posts?include=comments.author
    #   { posts: { include: { comments: { author: {} } } } }
    #
    # @example stats
    #   # GET /posts?stats[likes]=count,average
    #   { posts: { stats: [:count, :average] } }
    #
    # @example fields
    #   # GET /posts?fields=foo,bar
    #   { posts: { fields: [:foo, :bar] } }
    #
    # @example extra fields
    #   # GET /posts?fields=foo,bar
    #   { posts: { extra_fields: [:foo, :bar] } }
    #
    # @example nested parameters
    #   # GET /posts?include=comments&sort=comments.created_at&page[comments][size]=3
    #   {
    #     posts: { ... },
    #     comments: { page: { size: 3 }, sort: { created_at: :asc } }
    #
    # @see #default_hash
    # @see Base#query_hash
    # @return [Hash] the normalized query hash
    def to_hash
      hash = { resource.type => self.class.default_hash }

      association_names.each do |name|
        hash[name] = self.class.default_hash
      end

      fields = parse_fields({}, :fields)
      extra_fields = parse_fields({}, :extra_fields)
      hash.each_pair do |type, query_hash|
        hash[type][:fields] = fields
        hash[type][:extra_fields] = extra_fields
      end

      parse_filter(hash)
      parse_sort(hash)
      parse_pagination(hash)

      parse_include(hash, include_hash, resource.type)
      parse_stats(hash)

      hash
    end

    # Check if the user has requested 0 actual results
    # They may have done this to get, say, the total count
    # without the overhead of fetching actual records.
    #
    # @example Total Count, 0 Results
    #   # GET /posts?page[size]=0&stats[total]=count
    #   # Response:
    #   {
    #     data: [],
    #     meta: {
    #       stats: { total: { count: 100 } }
    #     }
    #   }
    #
    # @return [Boolean] were 0 results requested?
    def zero_results?
      !@params[:page].nil? &&
        !@params[:page][:size].nil? &&
        @params[:page][:size].to_i == 0
    end

    private

    def association?(name)
      resource.association_names.include?(name)
    end

    def parse_include(memo, incl_hash, namespace)
      memo[namespace] ||= self.class.default_hash
      memo[namespace].merge!(include: incl_hash)

      incl_hash.each_pair do |key, sub_hash|
        key = Util::Sideload.namespace(namespace, key)
        memo.merge!(parse_include(memo, sub_hash, key))
      end

      memo
    end

    def parse_stats(hash)
      if params[:stats]
        params[:stats].each_pair do |namespace, calculations|
          if namespace == resource.type || association?(namespace)
            calculations.each_pair do |name, calcs|
              hash[namespace][:stats][name] = calcs.split(',').map(&:to_sym)
            end
          else
            hash[resource.type][:stats][namespace] = calculations.split(',').map(&:to_sym)
          end
        end
      end
    end

    def parse_fields(hash, type)
      field_params = Util::FieldParams.parse(params[type])
      hash[type] = field_params
    end

    def parse_filter(hash)
      if filter = params[:filter]
        filter.each_pair do |key, value|
          key = key.to_sym

          if association?(key)
            hash[key][:filter].merge!(value)
          else
            hash[resource.type][:filter][key] = value
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
            hash[resource.type][:sort] << sort_attr(s)
          end
        end
      end
    end

    def parse_pagination(hash)
      if pagination = params[:page]
        pagination.each_pair do |key, value|
          key = key.to_sym

          if [:number, :size].include?(key)
            hash[resource.type][:page][key] = value.to_i
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
