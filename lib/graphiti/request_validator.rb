module Graphiti
  class RequestValidator
    attr_reader :errors

    def initialize(root_resource, raw_params)
      @root_resource = root_resource
      @raw_params = raw_params
      @errors = Graphiti::Util::SimpleErrors.new(raw_params)
    end

    def validate
      @normalized_payload = {
        attributes: deserialized_params.attributes,
        meta: deserialized_params.meta,
        relationships: deserialized_params.relationships,
      }

      typecast_attributes(@root_resource, @normalized_payload[:attributes], @normalized_payload[:meta][:payload_path])
      process_relationships(@root_resource, @normalized_payload[:relationships], @normalized_payload[:meta][:payload_path])

      errors.blank?
    end

    attr_reader :normalized_payload

    private

    def process_relationships(resource, relationships, payload_path)
      opts = {
        resource: resource,
        relationships: relationships,
      }

      Graphiti::Util::RelationshipPayload.iterate(opts) do |x|
        sideload_def = x[:sideload]

        unless sideload_def.writable?
          full_key = fully_qualified_key(sideload_def.name, payload_path, :relationships)
          unless @errors.added?(full_key, :unwritable_relationship)
            @errors.add(full_key, :unwritable_relationship)
          end
          next
        end

        typecast_attributes(x[:resource], x[:attributes], x[:meta][:payload_path])
        process_relationships(x[:resource], x[:relationships], x[:meta][:payload_path])
      end
    end

    def typecast_attributes(resource, attributes, payload_path)
      attributes.each_pair do |key, value|
        begin
          attributes[key] = resource.typecast(key, value, :writable)
        rescue Graphiti::Errors::UnknownAttribute
          @errors.add(fully_qualified_key(key, payload_path), :unknown_attribute)
        rescue Graphiti::Errors::InvalidAttributeAccess
          @errors.add(fully_qualified_key(key, payload_path), :unwritable_attribute, message: "cannot be written")
        rescue Graphiti::Errors::TypecastFailed => e
          @errors.add(fully_qualified_key(key, payload_path), :type_error, message: "should be type #{e.type_name}")
        end
      end
    end

    def normalized_params
      normalized = @raw_params
      if normalized.respond_to?(:to_unsafe_h)
        normalized = normalized.to_unsafe_h.deep_symbolize_keys
      end
      normalized
    end

    def deserialized_params
      @deserialized_params ||= begin
        payload = normalized_params
        if payload[:data] && payload[:data][:type]
          Graphiti::Deserializer.new(payload)
        end
      end
    end

    def fully_qualified_key(key, path, attributes_or_relationships = :attributes)
      (path + [attributes_or_relationships, key]).join(".")
    end
  end
end
