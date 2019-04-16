module Graphiti
  module Util
    class SerializerAttribute
      def initialize(name, attr, resource, serializer, extra)
        @name = name
        @attr = attr
        @resource = resource
        @serializer = serializer
        @extra = extra
      end

      def apply
        return unless readable?

        if @name == :id
          @serializer.id(&proc)
        elsif @attr[:proc]
          @serializer.send(_method, @name, serializer_options, &proc)
        elsif @serializer.attribute_blocks[@name].nil?
          @serializer.send(_method, @name, serializer_options, &proc)
        else
          unless @serializer.send(applied_method).include?(@name)
            inner = @serializer.attribute_blocks.delete(@name)
            wrapped = wrap_proc(inner)
            @serializer.send(_method, @name, serializer_options, &wrapped)
          end
        end

        existing = @serializer.send(applied_method)
        @serializer.send(:"#{applied_method}=", [@name] | existing)
      end

      private

      def applied_method
        if extra?
          :extra_attributes_applied_via_resource
        else
          :attributes_applied_via_resource
        end
      end

      def _method
        extra? ? :extra_attribute : :attribute
      end

      def extra?
        !!@extra
      end

      def readable?
        !!@attr[:readable]
      end

      def guard
        method_name = @attr[:readable]
        instance = @resource.new

        -> {
          method = instance.method(method_name)
          if method.arity.zero?
            instance.instance_eval(&method_name)
          else
            instance.instance_exec(@object, &method)
          end
        }
      end

      def guard?
        @attr[:readable] != true
      end

      def serializer_options
        {}.tap do |opts|
          opts[:if] = guard if guard?
        end
      end

      def typecast(type)
        resource_ref = @resource
        name_ref = @name
        type_ref = type
        ->(value) {
          begin
            type_ref[value] unless value.nil?
          rescue => e
            raise Errors::TypecastFailed.new(resource_ref, name_ref, value, e, type_ref)
          end
        }
      end

      def default_proc
        name_ref = @name
        typecast_ref = typecast(Graphiti::Types[@attr[:type]][:read])
        ->(_) {
          val = @object.send(name_ref)
          if Graphiti.config.typecast_reads
            typecast_ref.call(val)
          else
            val
          end
        }
      end

      def wrap_proc(inner)
        typecast_ref = typecast(Graphiti::Types[@attr[:type]][:read])
        ->(serializer_instance = nil) {
          val = serializer_instance.instance_eval(&inner)
          if Graphiti.config.typecast_reads
            typecast_ref.call(val)
          else
            val
          end
        }
      end

      def proc
        @attr[:proc] ? wrap_proc(@attr[:proc]) : default_proc
      end
    end

    class SerializerAttributes
      def initialize(resource, attributes, extra = false)
        @resource = resource
        @serializer = resource.serializer
        @attributes = attributes
        @extra = extra
      end

      def apply
        @attributes.each_pair do |name, attr|
          SerializerAttribute
            .new(name, attr, @resource, @serializer, @extra).apply
        end
      end
    end
  end
end
