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

      # If we can't eagerly validate links on app boot, we do it at runtime
      # To avoid any performance confusion, this caches that lookup
      def self.validated_link_cache
        @validated_link_cache ||= []
      end

      private

      def block
        _link = link?
        _resource_class = @resource_class
        _sl = @sideload
        _data_proc = data_proc
        _self = self
        validate_link! if eagerly_validate_links?

        proc do
          data { instance_eval(&_data_proc) }

          if _link
            if _links = @proxy.query.links?
              _self.send(:validate_link!) unless _self.send(:eagerly_validate_links?)

              link(:related) do
                if _links
                  ::Graphiti::Util::Link.new(_sl, @object).generate
                end
              end
            end
          end
        end
      end

      def data_proc
        _sl = @sideload
        ->(_) {
          if records = @object.public_send(_sl.association_name)
            if records.respond_to?(:to_ary)
              records.each { |r| _sl.resource.decorate_record(r) }
            else
              _sl.resource.decorate_record(records)
            end

            records
          end
        }
      end

      def eagerly_validate_links?
        if defined?(::Rails)
          ::Rails.application.config.eager_load
        else
          true
        end
      end

      def validate_link!
        return unless link?
        return unless @resource_class.validate_endpoints?
        return if @sideload.link_proc

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
        cache_key = :"#{@sideload.object_id}-#{action}"
        return if self.class.validated_link_cache.include?(cache_key)
        prc = Graphiti.config.context_for_endpoint
        unless prc.call(sideload.resource.endpoint[:full_path], action)
          raise Errors::InvalidLink.new(@resource_class, sideload, action)
        end
        self.class.validated_link_cache << cache_key
      end

      def link?
        return true if @sideload.link_proc

        if @sideload.respond_to?(:children)
          @sideload.link? &&
            @sideload.children.values.all? { |c| !c.resource.endpoint.nil? }
        else
          !!(@sideload.link? && @sideload.resource.endpoint)
        end
      end
    end
  end
end
