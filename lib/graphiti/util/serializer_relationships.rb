module Graphiti
  module Util
    class SerializerRelationships
      def initialize(resource_class, sideloads)
        @resource_class = resource_class
        @serializer = @resource_class.serializer
        @sideloads = sideloads
      end

      def apply
        @sideloads.each_pair do |name, sideload|
          if apply?(sideload)
            SerializerRelationship
              .new(@resource_class, @serializer, sideload).apply
          end
        end
      end

      private

      def apply?(sideload)
        @serializer.relationship_blocks[sideload.name].nil? &&
          sideload.readable?
      end
    end

    class SerializerRelationship
      def initialize(resource_class, serializer, sideload)
        @resource_class = resource_class
        @serializer = serializer
        @sideload = sideload
      end

      def apply
        @serializer.relationship(@sideload.name, &block)
      end

      private

      def block
        if _link = link?
          if @resource_class.validate_endpoints?
            validate_link! unless @sideload.link_proc
          end
        end

        _sl = @sideload
        _data_proc = data_proc
        proc do
          data { instance_eval(&_data_proc) }

          if _link
            if @proxy.query.links?
              link(:related) do
                ::Graphiti::Util::Link.new(_sl, @object).generate
              end
            end
          end
        end
      end

      def data_proc
        _sl = @sideload
        ->(_) {
          if records = @object.public_send(_sl.name)
            if records.respond_to?(:to_ary)
              records.each { |r| _sl.resource.decorate_record(r) }
            else
              _sl.resource.decorate_record(records)
            end

            records
          end
        }
      end

      def validate_link!
        unless Graphiti.config.context_for_endpoint
          raise Errors::Unlinkable.new(@resource_class, @sideload)
        end

        if @sideload.type == :polymorphic_belongs_to
          @sideload.children.each_pair do |name, sideload|
            _validate_link!(sideload)
          end
        else
          _validate_link!(@sideload)
        end
      end

      def _validate_link!(sideload)
        action = sideload.type == :belongs_to ? :show : :index
        prc = Graphiti.config.context_for_endpoint
        unless prc.call(sideload.resource.endpoint[:full_path], action)
          raise Errors::InvalidLink.new(@resource_class, sideload, action)
        end
      end

      def link?
        return true if @sideload.link_proc

        if @sideload.respond_to?(:children)
          @sideload.link? &&
            @sideload.children.values.all? { |c| !c.resource.endpoint.nil? }
        else
          @sideload.link? && @sideload.resource.endpoint
        end
      end
    end
  end
end
