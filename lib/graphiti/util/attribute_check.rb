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
        if attribute?
          if supported?
            if guarded?
              if guard_passes?
                attribute
              else
                maybe_raise(request: true, guard: attribute[flag])
              end
            else
              attribute
            end
          else
            maybe_raise(exists: true)
          end
        else
          maybe_raise(exists: false)
        end
      end

      def maybe_raise(opts = {})
        default = {request: request, exists: true}
        opts = default.merge(opts)
        error_class = opts[:exists] ?
          Graphiti::Errors::InvalidAttributeAccess :
          Graphiti::Errors::UnknownAttribute

        if raise_error?(opts[:exists])
          raise error_class.new(resource, name, flag, opts)
        else
          false
        end
      end

      def guard_passes?
        !!resource.send(attribute[flag])
      end

      def guarded?
        request? &&
          attribute[flag].is_a?(Symbol) &&
          attribute[flag] != :required
      end

      def supported?
        attribute[flag] != false
      end

      def attribute
        @attribute ||= resource.all_attributes[name]
      end

      def attribute?
        !!attribute
      end

      def raise_error?(exists)
        if raise_error == :only_unsupported
          exists ? true : false
        else
          !!raise_error
        end
      end

      def request?
        !!request
      end
    end
  end
end
