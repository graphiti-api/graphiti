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

        remove_guard if previously_guarded?

        if @name == :id
          @serializer.id(&proc)
        elsif @attr[:proc] ||
            !previously_applied? ||
            previously_applied_via_resource?
          @serializer.send(_method, @name, serializer_options, &proc)
        else # Previously applied via explicit serializer, so wrap it
          inner = @serializer.attribute_blocks.delete(@name)
          wrapped = wrap_proc(inner)
          @serializer.send(_method, @name, serializer_options, &wrapped)
        end

        existing = @serializer.send(applied_method)
        @serializer.send(:"#{applied_method}=", [@name] | existing)

        @serializer.meta do
          if !!@resource.try(:cursor_paginatable?) && !Graphiti.context[:graphql]
            {cursor: cursor}
          end
        end
      end

      private

      def previously_applied?
        @serializer.attribute_blocks[@name].present?
      end

      def previously_applied_via_resource?
        @serializer.send(applied_method).include?(@name)
      end

      def previously_guarded?
        @serializer.field_condition_blocks[@name]
      end

      def remove_guard
        @serializer.field_condition_blocks.delete(@name)
      end

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
        attribute = @name.to_s
        resource_class = @resource

        -> {
          method = instance.method(method_name)
          result = if method.arity.zero?
            instance.instance_eval(&method_name)
          elsif method.arity == 1
            instance.instance_exec(@object, &method)
          else
            instance.instance_exec(@object, attribute, &method)
          end
          if Graphiti.context[:graphql] && !result
            raise ::Graphiti::Errors::UnreadableAttribute.new(resource_class, attribute)
          end
          result
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
