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
          raise error_class.new(resource, name, flag, **opts)
        else
          false
        end
      end

      # Guards may optionally accept the model being written and the attribute
      # name, mirroring readable guards.
      def guard_passes?
        result = case guard_arity
        when 0 then call_guard
        when 1 then call_guard(resource.guard_model)
        else call_guard(resource.guard_model, name.to_s)
        end
        !!result
      end

      def call_guard(*args)
        if guard.is_a?(Proc)
          resource.instance_exec(*args, &guard)
        else
          resource.send(guard, *args)
        end
      end

      def guard_arity
        method = guard.is_a?(Proc) ? guard : resource.method(guard)
        # Negative arity means optional or splatted params - hand over
        # everything and let the guard take what it wants.
        method.arity.negative? ? 2 : method.arity
      end

      def guard
        attribute[flag]
      end

      def guarded?
        return false unless request?
        return false if guard == :required

        guard.is_a?(Symbol) || guard.is_a?(String) || guard.is_a?(Proc)
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
