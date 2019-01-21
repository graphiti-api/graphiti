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
        else
          if @serializer.attribute_blocks[@name].nil?
            @serializer.send(_method, @name, serializer_options, &proc)
          else
            unless @serializer.send(applied_method).include?(@name)
              inner = @serializer.attribute_blocks.delete(@name)
              wrapped = wrap_proc(inner)
              @serializer.send(_method, @name, serializer_options, &wrapped)
            end
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
          val = @object.send(_name)
          if Graphiti.config.typecast_reads
            _typecast.call(val)
          else
            val
          end
        }
      end

      def wrap_proc(inner)
        _resource = @resource.new
        _name = @name
        _typecast = typecast(Graphiti::Types[@attr[:type]][:read])
        ->(serializer_instance = nil) {
          val = serializer_instance.instance_eval(&inner)
          if Graphiti.config.typecast_reads
            _typecast.call(val)
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
