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
        link_ref = link?
        sideload_ref = @sideload
        data_proc_ref = data_proc
        self_ref = self
        validate_link! if eagerly_validate_links?

        proc do
          data { instance_eval(&data_proc_ref) }

          # include relationship links for belongs_to relationships
          # https://github.com/graphiti-api/graphiti/issues/167
          linkage always: sideload_ref.always_include_resource_ids?

          if link_ref
            if @proxy.query.links?
              self_ref.send(:validate_link!) unless self_ref.send(:eagerly_validate_links?)

              link(:related) do
                ::Graphiti::Util::Link.new(sideload_ref, @object).generate
              end
            end
          end
        end
      end

      def data_proc
        sideload_ref = @sideload
        ->(_) {
          if (records = @object.public_send(sideload_ref.association_name))
            if records.respond_to?(:to_ary)
              records.each { |r| sideload_ref.resource.decorate_record(r) }
            else
              sideload_ref.resource.decorate_record(records)
            end

            records
          end
        }
      end

      def eagerly_validate_links?
        # TODO: Maybe handle this in graphiti-rails
        if defined?(::Rails) && (app = ::Rails.application)
          app.config.eager_load
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
            validate_link_for_sideload!(sideload)
          end
        else
          validate_link_for_sideload!(@sideload)
        end
      end

      def validate_link_for_sideload!(sideload)
        return if sideload.resource.remote?

        action = sideload.type == :belongs_to ? :show : :index
        cache_key = :"#{@sideload.object_id}-#{action}"
        return if self.class.validated_link_cache.include?(cache_key)
        prc = Graphiti.config.context_for_endpoint
        unless prc.call(sideload.resource.endpoint[:full_path].to_s, action)
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
