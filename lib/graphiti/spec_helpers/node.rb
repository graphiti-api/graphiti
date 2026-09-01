module Graphiti
  module SpecHelpers
    class Node
      attr_reader :attributes, :relationships

      def initialize(attributes, relationships, context)
        @attributes = attributes.with_indifferent_access
        @relationships = relationships.with_indifferent_access if relationships
        @context = context
      end

      def id
        Integer(rawid) # Only convert if using integer ids
      rescue ArgumentError
        rawid
      end

      def rawid
        @attributes["id"]
      end

      def jsonapi_type
        @attributes["jsonapi_type"]
      end

      def has_key?(key)
        @attributes.has_key?(key)
      end
      alias_method :key?, :has_key?

      def [](key)
        @attributes[key] || @attributes[key.to_s]
      end

      def []=(key, val)
        @attributes[key] = val
      end

      alias_method :to_hash, :attributes

      def method_missing(id, *args, &blk)
        if @attributes.has_key?(id)
          @attributes[id]
        else
          raise Errors::NoAttribute.new(id)
        end
      end

      def respond_to_missing?(id, include_private = false)
        @attributes.has_key?(id) || super
      end

      def link(relationship_name, name)
        if @relationships.has_key?(relationship_name)
          links = @relationships[relationship_name][:links]
          raise Errors::LinksNotFound.new(relationship_name) unless links
          links[name]
        else
          raise Errors::SideloadNotFound.new(relationship_name)
        end
      end

      def sideload(relationship_name)
        unless @relationships.has_key?(relationship_name)
          raise Errors::SideloadNotFound.new(relationship_name)
        end
        rel = @relationships[relationship_name]
        rel = rel[:data]
        return if rel.nil?
        if rel.is_a?(Hash)
          include_for(rel[:type], rel[:id])
        else
          rel.map { |r| include_for(r[:type], r[:id]) }
        end
      end
      alias_method :sideloads, :sideload

      private

      def include_for(type, id)
        data = @context.json["included"].find do |i|
          i["type"] == type && i["id"] == id
        end
        @context.node(from: data)
      end
    end
  end
end
