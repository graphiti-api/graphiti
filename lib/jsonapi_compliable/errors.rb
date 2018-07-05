module JsonapiCompliable
  module Errors
    class Base < StandardError;end

    class AttributeError < Base
      attr_reader :resource,
        :name,
        :flag,
        :exists,
        :request,
        :guard

      def initialize(resource, name, flag, **opts)
        @resource = resource
        @name = name
        @flag = flag
        @exists = opts[:exists] || false
        @request = opts[:request] || false
        @guard = opts[:guard]
      end

      def action
        if @request
          {
            sortable: 'sort on',
            filterable: 'filter on',
            readable: 'read'
          }[@flag]
        else
          {
            sortable: 'add sort',
            filterable: 'add filter',
            readable: 'read'
          }[@flag]
        end
      end

      def resource_name
        name = if @resource.is_a?(JsonapiCompliable::Resource)
          @resource.class.name
        else
          @resource.name
        end
        name || 'AnonymousResourceClass'
      end

      def message
        msg = "#{resource_name}: Tried to #{action} attribute #{@name.inspect}"
        if @exists
          if @guard
            msg << ", but the guard #{@guard.inspect} did not pass."
          else
            msg << ", but the attribute was marked #{@flag.inspect} => false."
          end
        else
          msg << ", but could not find an attribute with that name."
        end
        msg
      end
    end

    class PolymorphicChildNotFound < Base
      def initialize(resource_class, model)
        @resource_class = resource_class
        @model = model
      end

      def message
        <<-MSG
#{@resource_class}: Tried to find subclass with model #{@model.class}, but nothing found!

Make sure all your child classes are assigned and associated to the right models:

self.polymorphic = ['Subclass1Resource', 'Subclass2Resource']
        MSG
      end
    end

    class ValidationError < Base
      attr_reader :validation_response

      def initialize(validation_response)
        @validation_response = validation_response
      end
    end

    class ModelNotFound < Base
      def initialize(resource_class)
        @resource_class = resource_class
      end

      def message
        <<-MSG
Could not find model for Resource '#{@resource_class}'

Manually set model (self.model = MyModel) if it does not match name of the Resource.
        MSG
      end
    end

    class TypeNotFound < Base
      def initialize(resource, attribute, type)
        @resource = resource
        @attribute = attribute
        @type = type
      end

      def message
        <<-MSG
Could not find type #{@type.inspect}! This was specified on attribute #{@attribute.inspect} within resource #{@resource.name}

Valid types are: #{JsonapiCompliable::Types.map.keys.inspect}
        MSG
      end
    end

    class PolymorphicChildNotFound < Base
      def initialize(sideload, name)
        @sideload = sideload
        @name = name
      end

      def message
        <<-MSG
#{@sideload.parent_resource}: Found record with #{@sideload.grouper.column_name.inspect} == #{@name.inspect}, which is not registered!

Register the behavior of different types like so:

polymorphic_belongs_to #{@sideload.name.inspect} do
  group_by(#{@sideload.grouper.column_name.inspect}) do
    on(#{@name.to_sym.inspect}) <---- this is what's missing
    on(:foo).belongs_to :foo, resource: FooResource (long-hand example)
  end
end
        MSG
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
      def initialize(resource, attributes)
        @resource = resource
        @attributes = Array(attributes)
      end

      def message
        if @attributes.length > 1
          "The required filters \"#{@attributes.join(', ')}\" on resource #{@resource.class} were not provided"
        else
          "The required filter \"#{@attributes[0]}\" on resource #{@resource.class} was not provided"
        end
      end
    end
  end
end
