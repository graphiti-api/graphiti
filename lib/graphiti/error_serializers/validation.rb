module Graphiti
  module ErrorSerializers
    # Walks into related objects so nested writes report against the record
    # that actually failed.
    class Validation
      include TranslatedTitle

      attr_reader :object

      def initialize(object, relationship_payloads = {}, relationship_meta = {})
        @object = object
        @relationship_payloads = relationship_payloads
        @relationship_meta = relationship_meta
      end

      def attribute_errors
        [].tap do |errors|
          each_error do |attribute, message, validation_code|
            errors << {
              code: code,
              status: "422",
              title: title,
              detail: detail_for(attribute, message),
              source: {pointer: pointer_for(object, attribute)},
              meta: meta_for(attribute, message, validation_code, @relationship_meta)
            }
          end
        end
      end

      def errors
        return [] unless object.respond_to?(:errors)

        attribute_errors | relationship_errors(object, @relationship_payloads)
      end

      private

      def code
        "unprocessable_entity"
      end

      def default_title
        "Validation Error"
      end

      def each_error
        object.errors.messages.each_pair do |attribute, messages|
          details = object.errors.details.find { |k, _| k == attribute }[1]

          messages.each_with_index do |message, index|
            yield attribute, message, details[index][:error]
          end
        end
      end

      def relationship?(name)
        relationship_names = []
        if activerecord?
          relationship_names = object.class
            .reflect_on_all_associations.map(&:name)
        elsif object.respond_to?(:relationship_names)
          relationship_names = object.relationship_names
        end

        relationship_names.include?(name)
      end

      def attribute?(name)
        object.respond_to?(name)
      end

      def meta_for(attribute, message, code, relationship_meta)
        meta = {
          attribute: attribute,
          message: message,
          code: code
        }

        unless relationship_meta.empty?
          meta = {relationship: meta.merge(relationship_meta)}
        end

        meta
      end

      def detail_for(attribute, message)
        detail = object.errors.full_message(attribute, message)
        detail = message if attribute.to_s.downcase == "base"
        detail
      end

      # @richmolj: Keeping this to support ember-data, but I hate the concept.
      def pointer_for(object, name)
        if relationship?(name)
          "/data/relationships/#{name}"
        elsif attribute?(name)
          "/data/attributes/#{name}"
        elsif name == :base
          nil
        else
          # Probably a nested relation, like post.comments
          "/data/relationships/#{name}"
        end
      end

      def activerecord?
        object.class.respond_to?(:reflect_on_all_associations)
      end

      def traverse_relationships(model, relationship_params)
        return unless relationship_params

        relationship_params.each_pair do |name, payload|
          relationship_objects = Array(model.send(name))

          relationship_objects.each do |relationship_object|
            related_payload = payload
            if payload.is_a?(Array)
              related_payload = payload.find { |p|
                temp_id = relationship_object
                  .instance_variable_get(:@_jsonapi_temp_id)
                p[:meta][:temp_id] === temp_id ||
                  p[:meta][:id] == relationship_object.id.to_s
              }
            end

            yield name, relationship_object, related_payload
            relationship_errors(relationship_object, related_payload[:relationships])
          end
        end
      end

      def relationship_errors(model, relationship_payloads)
        errors = []
        traverse_relationships(model, relationship_payloads) do |name, related, payload|
          meta = {}.tap do |hash|
            hash[:name] = name
            hash[:type] = payload[:meta][:jsonapi_type]
            if (temp_id = related.instance_variable_get(:@_jsonapi_temp_id))
              hash[:"temp-id"] = temp_id
            else
              hash[:id] = related.id
            end
          end

          errors |= self.class.new(related, payload[:relationships], meta).errors
        end
        errors
      end
    end
  end
end
