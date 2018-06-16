module JsonapiCompliable
  module Errors
    class Base < StandardError;end
    class BadFilter < Base; end

    class ValidationError < Base
      attr_reader :validation_response

      def initialize(validation_response)
        @validation_response = validation_response
      end
    end

    class ResourceNotFound < Base
      def initialize(resource, sideload_name)
        @resource = resource
        @sideload_name = sideload_name
      end

      def message
        <<-MSG
Could not find resource class for sideload '#{@sideload_name}' on Resource '#{@resource.class.name}'!

If this follows a non-standard naming convention, use the :resource option to pass it directly:

has_many :comments, resource: SpecialCommentResource
        MSG
      end
    end

    class UnsupportedPagination < Base
      def message
        <<-MSG
It looks like you are requesting pagination of a sideload, but there are > 1 parents.

This is not supported. In other words, you can do

/employees/1?include=positions&page[positions][size]=2

But not

/employees?include=positions&page[positions][size]=2

This is a limitation of most datastores; the same issue exists in ActiveRecord.

Consider using a named relationship instead, e.g. 'has_one :top_comment'
        MSG
      end
    end

    class MissingSerializer < Base
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

    class MissingSerializer < Base
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

    class UnsupportedPageSize < Base
      def initialize(size, max)
        @size, @max = size, max
      end

      def message
        "Requested page size #{@size} is greater than max supported size #{@max}"
      end
    end

    class InvalidInclude < Base
      def initialize(relationship, parent_resource)
        @relationship = relationship
        @parent_resource = parent_resource
      end

      def message
        "The requested included relationship \"#{@relationship}\" is not supported on resource \"#{@parent_resource}\""
      end
    end

    class StatNotFound < Base
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

    class RecordNotFound < Base
    end

    class RequiredFilter < Base
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
