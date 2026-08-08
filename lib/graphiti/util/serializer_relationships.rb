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
        return true if @serializer.relationship_blocks[sideload.name].nil?

        # A subclass inherits its parent's relationship blocks, each closed
        # over the parent's sideload. Redeclaring the relationship has to
        # replace that block or the override never reaches the payload.
        # Anything not generated here was written by hand, so leave it.
        applied = @serializer.relationship_sideloads[sideload.name]
        !applied.nil? && !applied.equal?(sideload)
      end
    end

    class SerializerRelationship
      def initialize(resource_class, serializer, sideload)
        @resource_class = resource_class
        @serializer = serializer
        @sideload = sideload
      end

      def apply
        sideload = @sideload
        # Reassign rather than mutate: ancestors share the hash by reference
        # until a subclass writes to it.
        @serializer.relationship_sideloads =
          @serializer.relationship_sideloads.merge(@sideload.name => @sideload)
        @serializer.relationship(@sideload.name, if: -> { sideload.readable? }, &block)
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

          # An included relationship is already loaded, and a customized
          # sideload can resolve it to something the foreign key alone would
          # not predict, so the loaded records win. Only the un-included case
          # is worth short-circuiting.
          if sideload_ref.resource_ids_from_foreign_key? &&
              !self_ref.send(:included_anywhere?, @proxy.query.include_hash, sideload_ref.name)
            linkage always: sideload_ref.render_resource_ids? do
              foreign_key = @object.public_send(sideload_ref.foreign_key)

              unless foreign_key.nil?
                {
                  type: sideload_ref.resource.type,
                  id: foreign_key.to_s
                }
              end
            end
          else
            linkage always: sideload_ref.render_resource_ids?
          end

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

      # A relationship nested under another one is still loaded and can still
      # be narrowed by a deep filter, so the foreign key is not a safe
      # stand-in for what the request actually returns.
      def included_anywhere?(include_hash, name)
        include_hash.any? do |key, nested|
          key == name || included_anywhere?(nested, name)
        end
      end

      def data_proc
        sideload_ref = @sideload
        resource_class_ref = @resource_class
        ->(_) {
          records = @object.public_send(sideload_ref.association_name)

          if records
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
        # TODO: Maybe handle this in the Rails integration
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
