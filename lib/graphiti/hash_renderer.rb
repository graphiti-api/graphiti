module Graphiti
  module SerializableHash
    def to_hash(fields: nil, include: {}, name_chain: [], graphql: false)
      {}.tap do |hash|
        fields_list = fields[jsonapi_type] if fields
        if fields_list.nil?
          fields_list = fields[name_chain.join(".").to_sym]
        end

        # polymorphic resources
        if @resource.respond_to?(:type) && @resource.type != jsonapi_type
          if fields[@resource.type]
            fields_list ||= []
            fields_list |= fields[@resource.type]
          end
        end

        attrs = requested_attributes(fields_list).each_with_object({}) { |(k, v), h|
          name = graphql ? k.to_s.camelize(:lower).to_sym : k
          h[name] = instance_eval(&v)
        }
        rels = @_relationships.select { |k, v| !!include[k] }
        rels.each_with_object({}) do |(k, v), h|
          serializers = v.send(:resources)
          name = graphql ? k.to_s.camelize(:lower) : k
          name_chain << k unless name_chain.last == k
          attrs[name.to_sym] = if serializers.is_a?(Array)
            serializers.map do |rr| # use private method to avoid array casting
              rr.to_hash(fields: fields, include: include[k], graphql: graphql, name_chain: name_chain)
            end
          elsif serializers.nil?
            if @resource.class.sideload(k).type.to_s.include?("_many")
              []
            end
          else
            serializers.to_hash(fields: fields, include: include[k], graphql: graphql, name_chain: name_chain)
          end
        end

        if !graphql || (fields_list || []).include?(:id)
          hash[:id] = jsonapi_id
        end
        if graphql && (fields_list || []).include?(:_type)
          hash[:_type] = jsonapi_type.to_s
        end
        hash.merge!(attrs) if attrs.any?
      end
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
      to_hash(serializers, opts).tap do |hash|
        hash.merge!(options.slice(:meta)) unless options[:meta].empty?
      end
    end

    private

    def to_hash(serializers, opts)
      {}.tap do |hash|
        top_level_key = :data
        if @graphql
          top_level_key = @resource.graphql_entrypoint
          unless serializers.is_a?(Array)
            top_level_key = top_level_key.to_s.singularize.to_sym
          end
        end

        hash[top_level_key] = if serializers.is_a?(Array)
          serializers.map do |s|
            s.to_hash(**opts)
          end
        else
          serializers.to_hash(**opts)
        end
      end
    end
  end
end
