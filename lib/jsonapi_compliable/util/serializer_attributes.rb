module JsonapiCompliable
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
          @serializer.id(&@attr[:proc]) if @attr[:proc]
        elsif @attr[:proc]
          @serializer.send(_method, @name, serializer_options, &proc)
        else
          if @serializer.attribute_blocks[@name].nil?
            @serializer.send(_method, @name, serializer_options, &proc)
          else
            inner = @serializer.attribute_blocks.delete(@name)
            wrapped = wrap_proc(inner)
            @serializer.send(_method, @name, serializer_options, &wrapped)
          end
        end
      end

      private

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
        _method = @attr[:readable]
        instance = @resource.new
        -> { instance.instance_eval(&_method) }
      end

      def guard?
        @attr[:readable] != true
      end

      def serializer_options
        {}.tap do |opts|
          opts[:if] = guard if guard?
        end
      end

      def default_proc
        type_name = @attr[:type]
        _name = @name
        _resource = @resource.new
        ->(_) {
          _resource.typecast(_name, @object.send(_name), :readable)
        }
      end

      def wrap_proc(inner)
        type_name = @attr[:type]
        ->(serializer_instance = nil) {
          type = JsonapiCompliable::Types[type_name]
          type[:read][serializer_instance.instance_eval(&inner)]
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
