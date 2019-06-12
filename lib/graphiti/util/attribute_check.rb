# Private, tested in resource specs
module Graphiti
  module Util
    class AttributeCheck
      attr_reader :resource, :name, :flag, :request, :raise_error

      def self.run(resource, name, flag, request, raise_error)
        new(resource, name, flag, request, raise_error).run
      end

      def initialize(resource, name, flag, request, raise_error)
        @resource = resource
        @name = name.to_sym
        @flag = flag
        @request = request
        @raise_error = raise_error
      end

      def run
        return attribute if guard_check! && attribute_check! && supported_check!

        false
      end

      def maybe_raise(opts = {})
        default     = { request: request, exists: true }
        opts        = default.merge(opts)
        exists      = opts[:exists]
        error_class = error_class(exists)

        raise error_class.new(resource, name, flag, opts) if raise_error?(exists)
      end

      def guard_passes?
        !!resource.send(attribute[flag])
      end

      def guarded?
        request? &&
          attribute? &&
          attribute[flag].is_a?(Symbol) &&
          attribute[flag] != :required
      end

      def supported?
        attribute? && attribute[flag] != false
      end

      def attribute
        @attribute ||= resource.all_attributes[name]
      end

      def attribute?
        !!attribute
      end

      def raise_error?(exists)
        if raise_error == :only_unsupported
          exists
        else
          raise_error
        end
      end

      def request?
        !!request
      end

      private

      def guard_check!
        return maybe_raise(guard: attribute[flag]) if guarded? && !guard_passes?

        true
      end

      def attribute_check!
        return maybe_raise(exists: false) if !attribute? && !attribute_missing?

        true
      end

      def attribute_missing?
        resource.attribute_missing(name)
        attribute?
      end

      def supported_check!
        return maybe_raise unless supported?

        true
      end

      def error_class(exists)
        exists ?
          Graphiti::Errors::InvalidAttributeAccess :
          Graphiti::Errors::UnknownAttribute
      end
    end
  end
end
