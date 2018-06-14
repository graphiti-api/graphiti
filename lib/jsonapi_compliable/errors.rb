module JsonapiCompliable
  module Errors
    class BadFilter < StandardError; end

    class ValidationError < StandardError
      attr_reader :validation_response

      def initialize(validation_response)
        @validation_response = validation_response
      end
    end

    class MissingSerializer < StandardError
      def initialize(class_name, serializer_name)
        @class_name = class_name
        @serializer_name = serializer_name
      end

      def message
        <<-MSG
Could not find serializer for class '#{@class_name}'!

Looked for '#{@serializer_name}' but doesn't appear to exist.

Use a custom Inferrer if you'd like different lookup logic.
        MSG
      end
    end

    class MissingSerializer < StandardError
      def initialize(class_name, serializer_name)
        @class_name = class_name
        @serializer_name = serializer_name
      end

      def message
        <<-MSG
Could not find serializer for class '#{@class_name}'!

Looked for '#{@serializer_name}' but doesn't appear to exist.

Use a custom Inferrer if you'd like different lookup logic.
        MSG
      end
    end

    class UnsupportedPageSize < StandardError
      def initialize(size, max)
        @size, @max = size, max
      end

      def message
        "Requested page size #{@size} is greater than max supported size #{@max}"
      end
    end

    class InvalidInclude < StandardError
      def initialize(relationship, parent_resource)
        @relationship = relationship
        @parent_resource = parent_resource
      end

      def message
        "The requested included relationship \"#{@relationship}\" is not supported on resource \"#{@parent_resource}\""
      end
    end

    class StatNotFound < StandardError
      def initialize(attribute, calculation)
        @attribute = attribute
        @calculation = calculation
      end

      def message
        "No stat configured for calculation #{pretty(@calculation)} on attribute #{pretty(@attribute)}"
      end

      private

      def pretty(input)
        if input.is_a?(Symbol)
          ":#{input}"
        else
          "'#{input}'"
        end
      end
    end

    class RecordNotFound < StandardError
    end

    class RequiredFilter < StandardError
      def initialize(attributes)
        @attributes = Array(attributes)
      end

      def message
        if @attributes.length > 1
          "The required filters \"#{@attributes.join(', ')}\" were not provided"
        else
          "The required filter \"#{@attributes[0]}\" was not provided"
        end
      end
    end
  end
end
