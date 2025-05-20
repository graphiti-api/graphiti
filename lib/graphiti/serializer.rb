module Graphiti
  class Serializer < JSONAPI::Serializable::Resource
    include Graphiti::Extensions::BooleanAttribute
    include Graphiti::Extensions::ExtraAttribute
    include Graphiti::SerializableHash
    prepend Graphiti::SerializableTempId

    # Keep track of what attributes have been applied by the Resource,
    # via .attribute, and which have been applied by a custom serializer
    # class/file.
    # This way, we can ensure attributes NOT applied by a resource still
    # go through type checking/coercion
    class_attribute :attributes_applied_via_resource
    class_attribute :extra_attributes_applied_via_resource
    class_attribute :relationship_condition_blocks
    self.attributes_applied_via_resource = []
    self.extra_attributes_applied_via_resource = []
    # See #requested_relationships
    self.relationship_condition_blocks ||= {}

    def self.inherited(klass)
      super
      klass.class_eval do
        extend JSONAPI::Serializable::Resource::ConditionalFields

        # See #requested_relationships
        def self.relationship(name, options = {}, &block)
          prev = Util::Hash.deep_dup(field_condition_blocks)
          super
          self.field_condition_blocks = prev
          _register_condition(relationship_condition_blocks, name, options)
        end

        # NB - avoid clobbering includes when sparse fieldset
        # https://github.com/jsonapi-rb/jsonapi-serializable/pull/102
        #
        # We also override this method to ensure attributes and relationships
        # have separate condition blocks. This way an attribute and
        # relationship can have the same name, and the attribute can be
        # conditional without affecting the relationship.
        def requested_relationships(fields)
          @_relationships.select do |k, _|
            _conditionally_included?(self.class.relationship_condition_blocks, k)
          end
        end
      end
    end

    def cursor
      starting_offset = 0
      page_param = @proxy.query.pagination
      if (page_number = page_param[:number])
        page_size = page_param[:size] || @resource.default_page_size
        starting_offset = (page_number - 1) * page_size
      end

      if (cursor = page_param[:after])
        starting_offset = cursor[:offset]
      end

      current_offset = @object.instance_variable_get(:@__graphiti_index)
      offset = starting_offset + current_offset + 1 # (+ 1 b/c o-base index)
      Base64.encode64({offset: offset}.to_json).chomp
    end

    def as_jsonapi(kwargs = {})
      super(**kwargs).tap do |hash|
        strip_relationships!(hash) if strip_relationships?
        add_links!(hash)
      end
    end

    # Allow access to resource methods
    def method_missing(id, ...)
      if @resource.respond_to?(id, true)
        @resource.send(id, ...)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = true)
      @resource.respond_to?(method_name, include_private) || super
    end

    private

    def add_links!(hash)
      return unless @resource.respond_to?(:links?)

      hash[:links] = @resource.links(@object) if @resource.links?
    end

    def strip_relationships!(hash)
      hash[:relationships]&.select! do |name, payload|
        payload.key?(:data)
      end
    end

    def strip_relationships?
      return false unless Graphiti.config.links_on_demand
      params = Graphiti.context[:object]&.params || {}

      [false, nil, "false"].include?(params[:links])
    end
  end
end
