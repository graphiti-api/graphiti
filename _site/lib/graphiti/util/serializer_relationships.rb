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
        if link?
          validate_link! unless @sideload.link_proc
          sl = @sideload
          proc do
            if @proxy.query.links?
              link(:related) do
                ::Graphiti::Util::Link.new(sl, @object).generate
              end
            end
          end
        else
          proc { }
        end
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
