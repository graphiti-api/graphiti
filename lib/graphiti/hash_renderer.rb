module Graphiti
  module SerializableHash
    def to_hash(fields: nil, include: {}, name_chain: [], graphql: false)
      {}.tap do |hash|
        if fields
          fields_list = nil

          # Dot syntax wins over jsonapi type
          if name_chain.length > 0
            fields_list = fields[name_chain.join(".").to_sym]
          end

          if fields_list.nil?
            fields_list = fields[jsonapi_type]
          end
        end

        # polymorphic resources - merge the PARENT type
        if polymorphic_subclass?
          if fields[@resource.type]
            fields_list ||= []
            fields_list |= fields[@resource.type]
          end

          if fields[jsonapi_type]
            fields_list ||= []
            fields_list |= fields[jsonapi_type]
          end
        end

        attrs = requested_attributes(fields_list).each_with_object({}) { |(k, v), h|
          name = graphql ? k.to_s.camelize(:lower).to_sym : k
          h[name] = instance_eval(&v)
        }

        # The main logic here is just !!include[k]
        # But we also have special on__<type>--<name> includes
        # Where we only include when matching the polymorphic type
        rels = @_relationships.select { |k, v|
          if include[k]
            true
          else
            included = false
            include.keys.each do |key|
              split = key.to_s.split(/^on__/)
              if split.length > 1
                requested_type, key = split[1].split("--")
                if requested_type.to_sym == jsonapi_type
                  included = k == key.to_sym
                  break
                end
              end
            end
            included
          end
        }

        rels.each_with_object({}) do |(k, v), h|
          nested_include = include[k]

          # This logic only fires if it's a special on__<type>--<name> include
          unless include.has_key?(k)
            include.keys.each do |include_key|
              if k == include_key.to_s.split("--")[1].to_sym
                nested_include = include[include_key]
                break
              end
            end
          end

          serializers = v.send(:resources)
          name = graphql ? k.to_s.camelize(:lower) : k
          name_chain = name_chain.dup
          name_chain << k unless name_chain.last == k

          unless remote_resource? && serializers.nil?
            payload = if serializers.is_a?(Array)
              data = serializers.map { |rr|
                rr.to_hash(fields: fields, include: nested_include, graphql: graphql, name_chain: name_chain)
              }
              graphql ? {nodes: data} : data
            elsif serializers.nil?
              if @resource.class.respond_to?(:sideload)
                if @resource.class.sideload(k).type.to_s.include?("_many")
                  graphql ? {nodes: []} : []
                end
              end
            else
              serializers.to_hash(fields: fields, include: nested_include, graphql: graphql, name_chain: name_chain)
            end

            attrs[name.to_sym] = payload
          end
        end

        if !graphql || (fields_list || []).include?(:id)
          hash[:id] = jsonapi_id
        end

        if (fields_list || []).include?(:_type)
          hash[:_type] = jsonapi_type.to_s
        end

        if (fields_list || []).include?(:_cursor)
          hash[:_cursor] = cursor
        end

        if (fields_list || []).include?(:__typename)
          resource_class = @resource.class
          if polymorphic_subclass?
            resource_class = @resource.class.resource_for_type(jsonapi_type)
          end
          hash[:__typename] = ::Graphiti::Util::Class
            .graphql_type_name(resource_class.name)
        end

        hash.merge!(attrs) if attrs.any?
      end
    end

    def polymorphic_subclass?
      !remote_resource? &&
        @resource.polymorphic? &&
        @resource.type != jsonapi_type
    end

    # See hack in util/remote_serializer.rb
    def remote_resource?
      @resource == 1
    end
  end

  class HashRenderer
    def initialize(resource, graphql: false)
      @resource = resource
      @graphql = graphql
    end

    def render(options)
      serializers = options[:data]
      opts = options.slice(:fields, :include)
      opts[:graphql] = @graphql
      top_level_key = get_top_level_key(@resource, serializers.is_a?(Array))

      hash = {top_level_key => {}}
      nodes = get_nodes(serializers, opts)
      add_nodes(hash, top_level_key, options, nodes, @graphql)
      add_stats(hash, top_level_key, options, @graphql)
      if @graphql
        add_page_info(hash, serializers, top_level_key, options)
      end

      hash
    end

    private

    def get_top_level_key(resource, is_many)
      key = :data

      if @graphql
        key = @resource.graphql_entrypoint
        key = key.to_s.singularize.to_sym unless is_many
      end

      key
    end

    def get_nodes(serializers, opts)
      if serializers.is_a?(Array)
        serializers.each_with_index.map do |s, index|
          s.to_hash(**opts)
        end
      else
        serializers.to_hash(**opts)
      end
    end

    def add_nodes(hash, top_level_key, opts, nodes, graphql)
      payload = nodes
      if graphql && nodes.is_a?(Array)
        payload = {nodes: nodes}
      end

      # Don't render nodes if we only requested stats
      unless graphql && opts[:fields].values == [[:stats]]
        hash[top_level_key] = payload
      end
    end

    def add_stats(hash, top_level_key, options, graphql)
      if options[:meta] && !options[:meta].empty?
        if @graphql
          if (stats = options[:meta][:stats])
            camelized = {}
            stats.each_pair do |key, value|
              camelized[key.to_s.camelize(:lower).to_sym] = value
            end
            hash[top_level_key][:stats] = camelized
          end
        else
          hash.merge!(options.slice(:meta))
        end
      end
    end

    # NB - this is only for top-level right now
    # The casing here is GQL-specific, we can update later if needed.
    def add_page_info(hash, serializers, top_level_key, options)
      if (fields = options[:fields].try(:[], :page_info))
        info = {}

        if fields.include?(:has_next_page)
          info[:hasNextPage] = options[:proxy].pagination.has_next_page?
        end

        if fields.include?(:has_previous_page)
          info[:hasPreviousPage] = options[:proxy].pagination.has_previous_page?
        end

        if fields.include?(:start_cursor)
          info[:startCursor] = serializers.first.try(:cursor)
        end

        if fields.include?(:end_cursor)
          info[:endCursor] = serializers.last.try(:cursor)
        end

        hash[top_level_key][:pageInfo] = info
      end
    end
  end
end
