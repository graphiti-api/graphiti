module Graphiti
  class RequestValidator
    delegate :vaildate,
             :validate!,
             :errors,
             :deserialized_payload,
             to: :@validator

    def initialize(root_resource, raw_params)
      @validator = ValidatorFactory.create(root_resource, raw_params)
    end

    class ValidatorFactory
      def self.create(root_resource, raw_params)
        case raw_params["action"]
        when "update" then
          UpdateValidator
        else
          Validator
        end.new(root_resource, raw_params)
      end
    end

    class Validator
      attr_reader :root_resource, :errors
      def initialize(root_resource, raw_params)
        @root_resource = root_resource
        @raw_params = raw_params
        @errors = Graphiti::Util::SimpleErrors.new(raw_params)
      end

      # FIXME: set resource in initializer and use the attr_reader instead of passing it around
      def validate
        resource = @root_resource
        if (meta_type = deserialized_payload.meta[:type].try(:to_sym))
          if @root_resource.type != meta_type && @root_resource.polymorphic?
            resource = @root_resource.class.resource_for_type(meta_type).new
          end
        end

        typecast_attributes(resource, deserialized_payload.attributes, deserialized_payload.meta[:payload_path])
        process_relationships(resource, deserialized_payload.relationships, deserialized_payload.meta[:payload_path])

        errors.blank?
      end

      def validate!
        unless validate
          raise @error_class || Graphiti::Errors::InvalidRequest, self.errors
        end

        true
      end

      def deserialized_payload
        @deserialized_payload ||= begin
                                    payload = normalized_params
                                    if payload[:data] && payload[:data][:type]
                                      Graphiti::Deserializer.new(payload)
                                    else
                                      Graphiti::Deserializer.new({})
                                    end
                                  end
      end

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
            resource.typecast(key, value, :writable)
            @errors.add(fully_qualified_key(key, payload_path), :unknown_attribute, message: "is an unknown attribute")
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

      def fully_qualified_key(key, path, attributes_or_relationships = :attributes)
        (path + [attributes_or_relationships, key]).join(".")
      end

      def missing_required_attribute(attr_path)
        @errors.add(
          attr_path.join("."),
          :missing_required_attribute,
          message: "is missing from the payload"
        )
      end

      def attribute_mismatch(attr_path)
        @error_class = Graphiti::Errors::ConflictRequest
        @errors.add(
          attr_path.join("."),
          :attribute_mismatch,
          message: "does not match the server endpoint"
        )
      end
    end

    class UpdateValidator < Validator
      def validate
        if required_payload? && payload_matches_endpoint?
          super
        else
          return false
        end
      end

      private

      def required_payload?
        [
          [:data],
          [:data, :type],
          [:data, :id]
        ].each do |required_attr|
          attribute_mismatch(required_attr) unless @raw_params.dig(*required_attr)
        end
        errors.blank?
      end

      def payload_matches_endpoint?
        unless @raw_params.dig(:data, :id) == @raw_params.dig(:filter, :id)
          attribute_mismatch([:data, :id])
        end

        meta_type = @raw_params.dig(:data, :type)
        if @root_resource.type != meta_type
          if @root_resource.polymorphic?
            begin
              @root_resource.class.resource_for_type(meta_type).new
            rescue Errors::PolymorphicResourceChildNotFound
              attribute_mismatch([:data, :type])
            end
          else
            attribute_mismatch([:data, :type])
          end
        end

        errors.blank?
      end
    end
  end
end
