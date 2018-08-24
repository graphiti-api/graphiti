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

      def typecast(type)
        _resource = @resource
        _name = @name
        _type = type
        ->(value) {
          begin
            _type[value] unless value.nil?
          rescue Exception => e
            raise Errors::TypecastFailed.new(_resource, _name, value, e)
          end
        }
      end

      def default_proc
        _name = @name
        _resource = @resource.new
        _typecast = typecast(Graphiti::Types[@attr[:type]][:read])
        ->(_) {
          _typecast.call(@object.send(_name))
        }
      end

      def wrap_proc(inner)
        _resource = @resource.new
        _name = @name
        _typecast = typecast(Graphiti::Types[@attr[:type]][:read])
        ->(serializer_instance = nil) {
          _typecast.call(serializer_instance.instance_eval(&inner))
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
