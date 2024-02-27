module Graphiti
  module Errors
    class Base < StandardError; end

    class UnreadableAttribute < Base
      def initialize(resource_class, name)
        @resource_class = resource_class
        @name = name
      end

      def message
        "#{@resource_class}: Requested field #{@name}, but not authorized to read it"
      end
    end

    class NullRelation
      attr_accessor :id, :errors, :pointer

      def initialize(id, pointer)
        @id = id
        @pointer = pointer
        @errors = Graphiti::Util::SimpleErrors.new(self)
      end

      def self.human_attribute_name(attr, options = {})
        attr
      end
    end

    class AdapterNotImplemented < Base
      def initialize(adapter, attribute, method)
        @adapter = adapter
        @attribute = attribute
        @method = method
      end

      def message
        <<~MSG
          The adapter #{@adapter.class} does not implement method '#{@method}', which was requested for attribute '#{@attribute}'. Add this method to your adapter to support this filter operator.
        MSG
      end
    end

    class SideloadConfig < Base
      def initialize(name, parent_resource_class, message)
        @name = name
        @parent_resource_class = parent_resource_class
        @message = message
      end

      def message
        <<~MSG
          #{@parent_resource_class} sideload :#{@name} - #{@message}
        MSG
      end
    end

    class Remote < Base
      def initialize(url, errors)
        @url = url
        @errors = errors
      end

      def message
        msg = "Error hitting remote API: #{@url}"
        @errors.each do |e|
          msg << "\n\n#{e[:message]}"
          msg << "\n\n#{e[:backtrace].join("\n")}\n\n\n\n" if e[:backtrace]
        end
        msg
      end
    end

    class AroundCallbackProc < Base
      def initialize(resource_class, method_name)
        @resource_class = resource_class
        @method_name = method_name
      end

      def message
        <<~MSG
          #{@resource_class}: Tried to pass block to .#{@method_name}, which only accepts a method name.
        MSG
      end
    end

    class RemoteWrite < Base
      def initialize(resource_class)
        @resource_class = resource_class
      end

      def message
        <<~MSG
          #{@resource_class}: Tried to perform write operation. Writes are not supported for remote resources - hit the endpoint directly.
        MSG
      end
    end

    class UnsupportedOperator < Base
      def initialize(resource, filter_name, supported, operator)
        @resource = resource
        @filter_name = filter_name
        @supported = supported
        @operator = operator
      end

      def message
        <<~MSG
          #{@resource.class}: Tried to filter #{@filter_name.inspect} on operator #{@operator.inspect}, but not supported! Supported operators are #{@supported}.
        MSG
      end
    end

    class SingularSideload < Base
      def initialize(sideload, parent_length)
        @sideload = sideload
        @parent_length = parent_length
      end

      def message
        <<~MSG
          #{@sideload.parent_resource.class.name}: tried to sideload #{@sideload.name.inspect}, but more than one #{@sideload.parent_resource.model.name} was passed!

          This is because you marked the sideload #{@sideload.name.inspect} with single: true

          You might have done this because the sideload can only be loaded from a :show endpoint, and :index would be too expensive.

          Remove the single: true option to bypass this error.
        MSG
      end
    end

    class UnsupportedSort < Base
      def initialize(resource, attribute, allowlist, direction)
        @resource = resource
        @attribute = attribute
        @allowlist = allowlist
        @direction = direction
      end

      def message
        <<~MSG
          #{@resource.class.name}: tried to sort on attribute #{@attribute.inspect}, but passed #{@direction.inspect} when only #{@allowlist.inspect} is supported.
        MSG
      end
    end

    class ExtraAttributeNotFound < Base
      def initialize(resource_class, name)
        @resource_class = resource_class
        @name = name
      end

      def message
        <<~MSG
          #{@resource_class.name}: called .on_extra_attribute #{@name.inspect}, but extra attribute #{@name.inspect} does not exist!
        MSG
      end
    end

    class InvalidFilterValue < Base
      def initialize(resource, filter, value)
        @resource = resource
        @filter = filter
        @value = value
      end

      def message
        allow = @filter.values[0][:allow]
        deny = @filter.values[0][:deny]
        value_string = if @value == "(empty)"
          "empty value"
        else
          "value #{@value.inspect}"
        end
        msg = <<~MSG
          #{@resource.class.name}: tried to filter on #{@filter.keys[0].inspect}, but passed invalid #{value_string}.
        MSG
        msg << "\nAllowlist: #{allow.inspect}" if allow
        msg << "\nDenylist: #{deny.inspect}" if deny
        msg
      end
    end

    class MissingEnumAllowList < Base
      def initialize(resource_class, filter_name, enum_type)
        @resource_class = resource_class
        @filter_name = filter_name
        @enum_type = enum_type
      end

      def message
        <<~MSG
          #{@resource_class.name} You declared an attribute or filter of type "#{@enum_type}" without providing a list of permitted values, which is required.

          When declaring an attribute:

          attribute :status, :#{@enum_type}, allow: ['published', 'draft']

          When declaring a filter:

          filter :status, :#{@enum_type}, allow: ['published', 'draft'] do
            # ...
          end
        MSG
      end
    end

    class InvalidLink < Base
      def initialize(resource_class, sideload, action)
        @resource_class = resource_class
        @sideload = sideload
        @action = action
      end

      def message
        <<~MSG
          #{@resource_class.name}: Cannot link to sideload #{@sideload.name.inspect}!

          Make sure the endpoint "#{@sideload.resource.endpoint[:full_path]}" exists with action #{@action.inspect}, or customize the endpoint for #{@sideload.resource.class.name}.

          If you do not wish to generate a link, pass link: false or set self.autolink = false.
        MSG
      end
    end

    class SingularFilter < Base
      def initialize(resource, filter, value)
        @resource = resource
        @filter = filter
        @value = value
      end

      def message
        <<-MSG
          #{@resource.class.name}: passed multiple values to filter #{@filter.keys[0].inspect}, which was marked single: true.

          Value was: #{@value.inspect}
        MSG
      end
    end

    class Unlinkable < Base
      def initialize(resource_class, sideload)
        @resource_class = resource_class
        @sideload = sideload
      end

      def message
        <<-MSG
          #{@resource_class.name}: Tried to link sideload #{@sideload.name.inspect}, but cannot generate links!

          Graphiti.config.context_for_endpoint must be set to enable link generation:

          Graphiti.config.context_for_endpoint = ->(path, action) { ... }
        MSG
      end
    end

    class SideloadParamsError < Base
      def initialize(resource_class, sideload_name)
        @resource_class = resource_class
        @sideload_name = sideload_name
      end

      def message
        <<-MSG
          #{@resource_class.name}: error occurred while sideloading "#{@sideload_name}"!

          The error was raised while attempting to build query parameters for the associated Resource.
          Read more about sideload scoping here: www.graphiti.dev/guides/concepts/resources#customizing-scope

          A good way to debug is to put a debugger within the 'params' block.

          Here's the original, underlying error:

          #{cause.class.name}: #{cause}
          #{cause.backtrace.join("\n")}
        MSG
      end
    end

    class SideloadQueryBuildingError < Base
      def initialize(resource_class, sideload_name)
        @resource_class = resource_class
        @sideload_name = sideload_name
      end

      def message
        <<-MSG
          #{@resource_class.name}: error occurred while sideloading "#{@sideload_name}"!

          The error was raised while attempting to build the scope for the associated Resource.

          Read more about sideload scoping here: www.graphiti.dev/guides/concepts/resources#customizing-scope

          Here's the original, underlying error:

          #{cause.class.name}: #{cause.message}
          #{cause.backtrace.join("\n")}
        MSG
      end
    end

    class SideloadAssignError < Base
      def initialize(resource_class, sideload_name)
        @resource_class = resource_class
        @sideload_name = sideload_name
      end

      def message
        <<-MSG
          #{@resource_class.name}: error occurred while sideloading "#{@sideload_name}"!

          The error was raised while attempting to assign relevant model instances. Read
          more about sideload assignment here: www.graphiti.dev/guides/concepts/resources#customizing-assignment

          A good way to debug is to put a debugger within the 'assign' block.

          Here's the original, underlying error:

          #{cause.class.name}: #{cause.message}
          #{cause.backtrace.join("\n")}
        MSG
      end
    end

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
        @request = opts[:request] || false
      end

      def action
        if @request
          {
            sortable: "sort on",
            filterable: "filter on",
            readable: "read",
            writable: "write"
          }[@flag]
        else
          {
            sortable: "add sort",
            filterable: "add filter",
            readable: "read",
            writable: "write"
          }[@flag]
        end
      end

      def resource_name
        name = if @resource.is_a?(Graphiti::Resource)
          @resource.class.name
        else
          @resource.name
        end
        name || "AnonymousResourceClass"
      end

      def message
        "#{resource_name}: Tried to #{action} attribute #{@name.inspect}"
      end
    end

    class InvalidAttributeAccess < AttributeError
      def initialize(resource, name, flag, **opts)
        super
        @guard = opts[:guard]
      end

      def message
        msg = super

        msg << if @guard
          ", but the guard #{@guard.inspect} did not pass."
        else
          ", but the attribute was marked #{@flag.inspect} => false."
        end

        msg
      end
    end

    class UndefinedIDLookup < Base
      def initialize(resource_class)
        @resource_class = resource_class
      end

      def message
        <<~MSG
          Tried to resolve #{@resource_class} with an :id filter, but the filter was nil.
          This can result in unscoping a query, which can cause incorrect values to be
          returned which may or may not bypass standard access controls.
        MSG
      end
    end

    class UnknownAttribute < AttributeError
      def message
        "#{super}, but could not find an attribute with that name."
      end
    end

    class InvalidJSONArray < Base
      def initialize(resource, value)
        @resource = resource
        @value = value
      end

      def message
        <<-MSG
          #{@resource.class.name}: passed filter with value #{@value.inspect}, and failed attempting to parse as JSON array.
        MSG
      end
    end

    class InvalidEndpoint < Base
      def initialize(resource_class, path, action)
        @resource_class = resource_class
        @path = path
        @action = action
      end

      def message
        <<-MSG
          #{@resource_class.name} cannot be called directly from endpoint #{@path}##{@action}!

          Either set a primary endpoint for this resource:

          primary_endpoint '/my/url', [:index, :show, :create]

          Or whitelist a secondary endpoint:

          secondary_endpoint '/my_url', [:index, :update]

          The current endpoints allowed for this resource are: #{@resource_class.endpoints.inspect}
        MSG
      end
    end

    class InvalidType < Base
      def initialize(key, value)
        @key = key
        @value = value
      end

      def message
        "Type must be a Hash with keys #{Types::REQUIRED_KEYS.inspect}"
      end
    end

    class ResourceEndpointConflict < Base
      def initialize(path, action, resource_a, resource_b)
        @path = path
        @action = action
        @resource_a = resource_a
        @resource_b = resource_b
      end

      def message
        <<~MSG
          Both '#{@resource_a}' and '#{@resource_b}' are associated to endpoint #{@path}##{@action}!

          Only one resource can be associated to a given url/verb combination.
        MSG
      end
    end

    class PolymorphicResourceChildNotFound < Base
      def initialize(resource_class, type: nil, model: nil)
        @resource_class = resource_class
        @model = model
        @type = type
      end

      def message
        @model ? model_message : type_message
      end

      def model_message
        <<~MSG
          #{@resource_class}: Tried to find Resource subclass with model #{@model.class}, but nothing found!

          Make sure all your child classes are assigned and associated to the right models:

          # One of these should be assocated to model #{@model.class}:
          self.polymorphic = ['Subclass1Resource', 'Subclass2Resource']
        MSG
      end

      def type_message
        <<~MSG
          #{@resource_class}: Tried to find Resource subclass with model #{@model.class}, but nothing found!

          Make sure all your child classes are assigned and associated to the right models:

          # One of these should be assocated to model #{@model.class}:
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

    class ImplicitFilterTypeMissing < Base
      def initialize(resource_class, name)
        @resource_class = resource_class
        @name = name
      end

      def message
        <<~MSG
          Tried to add filter-only attribute #{@name.inspect}, but type was missing!

          If you are adding a filter that does not have a corresponding attribute, you must pass a type:

          filter :name, :string do <--- like this
            # ... code ...
          end
        MSG
      end
    end

    class ImplicitSortTypeMissing < Base
      def initialize(resource_class, name)
        @resource_class = resource_class
        @name = name
      end

      def message
        <<~MSG
          Tried to add sort-only attribute #{@name.inspect}, but type was missing!

          If you are adding a sort that does not have a corresponding attribute, you must pass a type:

          sort :name, :string do <--- like this
            # ... code ...
          end
        MSG
      end
    end

    class TypecastFailed < Base
      attr_reader :name, :type_name

      def initialize(resource, name, value, error, type_name)
        @resource = resource
        @name = name
        @value = value
        @error = error
        @type_name = type_name
      end

      def message
        <<~MSG
          #{@resource.class}: Failed typecasting #{@name.inspect}! Given #{@value.inspect} but the following error was raised:

          #{@error.message}

          #{@error.backtrace.join("\n")}
        MSG
      end
    end

    class ModelNotFound < Base
      def initialize(resource_class)
        @resource_class = resource_class
      end

      def message
        <<~MSG
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
        <<~MSG
          Could not find type #{@type.inspect}! This was specified on attribute #{@attribute.inspect} within resource #{@resource.name}

          Valid types are: #{Graphiti::Types.map.keys.inspect}
        MSG
      end
    end

    class PolymorphicSideloadTypeNotFound < Base
      def initialize(sideload, name)
        @sideload = sideload
        @name = name
      end

      def message
        <<~MSG
          #{@sideload.parent_resource}: Tried to find a Resource with type '#{@name.inspect}', but did not find one!

          This is because either a Resource with that type doesn't exist, or it's not registered on the sideload. The below example shows how to register a Resource with this sideload. Make sure one of the registered Resources has type '#{@name.inspect}'

          polymorphic_belongs_to #{@sideload.name.inspect} do
            group_by(#{@sideload.grouper.field_name.inspect}) do
              on(:foo)
              on(:foo).belongs_to :foo, resource: FooResource # (long-hand example)
            end
          end
        MSG
      end
    end

    class PolymorphicSideloadChildNotFound < Base
      def initialize(sideload, name)
        @sideload = sideload
        @name = name
      end

      def message
        <<~MSG
          #{@sideload.parent_resource}: Found record with #{@sideload.grouper.field_name.inspect} == #{@name.inspect}, which is not registered!

          Register the behavior of different types like so:

          polymorphic_belongs_to #{@sideload.name.inspect} do
            group_by(#{@sideload.grouper.field_name.inspect}) do
              on(#{@name.to_sym.inspect}) <---- this is what's missing
              on(:foo).belongs_to :foo, resource: FooResource (long-hand example)
            end
          end
        MSG
      end
    end

    class MissingSideloadFilter < Base
      def initialize(resource_class, sideload, filter)
        @resource_class = resource_class
        @sideload = sideload
        @filter = filter
      end

      def message
        <<~MSG
          #{@resource_class.name}: sideload #{@sideload.name.inspect} is associated with resource #{@sideload.resource.class.name}, but it does not have corresponding filter.

          Expecting filter #{@filter.inspect} on #{@sideload.resource.class.name}.
        MSG
      end
    end

    class MissingDependentFilter < Base
      def initialize(resource, filters)
        @resource = resource
        @filters = filters
      end

      def message
        msg = "#{@resource.class.name}: The following filters had dependencies that were not passed:"
        @filters.each do |f|
          msg << "\n#{f[:filter][:name].inspect} - dependent on #{f[:filter][:dependencies].inspect}, but #{f[:missing].inspect} not passed."
        end
        msg
      end
    end

    class ResourceNotFound < Base
      def initialize(resource_class, sideload_name, tried)
        @resource_class = resource_class
        @sideload_name = sideload_name
        @tried = tried
      end

      def message
        <<~MSG
          Could not find resource class for sideload '#{@sideload_name}' on Resource '#{@resource_class.name}'!

          Tried to find classes: #{@tried.join(", ")}

          If this follows a non-standard naming convention, use the :resource option to pass it directly:

          has_many :comments, resource: SpecialCommentResource
        MSG
      end
    end

    class UnsupportedPagination < Base
      def message
        <<~MSG
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

    class UnsupportedBeforeCursor < Base
      def message
        "Passing in page[before] and page[number] is not supported. Please create an issue if you need it!"
      end
    end

    class InvalidInclude < Base
      def initialize(resource, relationship)
        @resource = resource
        @relationship = relationship
      end

      def message
        "#{@resource.class.name}: The requested included relationship \"#{@relationship}\" is not supported."
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
      def initialize(resource = nil, id = nil, path = nil)
        @resource = resource
        @id = id
        @path = path
      end

      def message
        if !@resource.nil? && !@id.nil?
          "The referenced resource '#{@resource}' with id '#{@id}' could not be found.".tap do |msg|
            msg << " Referenced at '#{@path}'" unless @path.nil?
          end
        else
          "Specified Record Not Found"
        end
      end
    end

    class RequiredFilter < Base
      def initialize(resource, attributes)
        @resource = resource
        @attributes = Array(attributes)
      end

      def message
        if @attributes.length > 1
          "The required filters \"#{@attributes.join(", ")}\" on resource #{@resource.class} were not provided"
        else
          "The required filter \"#{@attributes[0]}\" on resource #{@resource.class} was not provided"
        end
      end
    end

    class InvalidRequest < Base
      attr_reader :errors

      def initialize(errors)
        @errors = errors
      end

      def message
        <<-MSG
          There were one or more errors with your request:

          #{errors.full_messages.join("\n")}
        MSG
      end
    end

    class ConflictRequest < InvalidRequest
    end

    class FilterGroupInvalidRequirement < Base
      def initialize(resource, valid_required_values)
        @resource = resource
        @valid_required_values = valid_required_values
      end

      def message
        <<-MSG.gsub(/\s+/, " ").strip
          The filter group required: value on resource #{@resource.class} must be one of the following:
          #{@valid_required_values.join(", ")}
        MSG
      end
    end

    class FilterGroupMissingRequiredFilters < Base
      def initialize(resource, filter_names, required)
        @resource = resource
        @filter_names = filter_names
        @required_label = required == :all ? "All" : "One"
      end

      def message
        <<-MSG.gsub(/\s+/, " ").strip
          #{@required_label} of the following filters must be provided on resource #{@resource.type}:
          #{@filter_names.join(", ")}
        MSG
      end
    end
  end
end
