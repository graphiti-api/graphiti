module Graphiti
  class Resource
    include DSL
    include Interface
    include Configuration
    include Sideloading
    include Links
    include Documentation
    include Persistence

    def around_scoping(scope, query_hash)
      extra_fields = query_hash[:extra_fields] || {}
      extra_fields = extra_fields[type] || []
      extra_fields.each do |name|
        if (config = self.class.config[:extra_attributes][name])
          scope = instance_exec(scope, &config[:hook]) if config[:hook]
        end
      end

      yield scope
    end

    def after_filtering(scope)
      scope
    end

    def serializer_for(model)
      serializer
    end

    def decorate_record(record, index = nil)
      unless record.instance_variable_get(:@__graphiti_serializer)
        serializer = serializer_for(record)
        record.instance_variable_set(:@__graphiti_serializer, serializer)
        record.instance_variable_set(:@__graphiti_resource, self)
        record.instance_variable_set(:@__graphiti_index, index) if index
      end
    end

    def with_context(object, namespace = nil)
      Graphiti.with_context(object, namespace) do
        yield
      end
    end

    def self.context
      Graphiti.context[:object]
    end

    def context
      self.class.context
    end

    def self.context_namespace
      Graphiti.context[:namespace]
    end

    def context_namespace
      self.class.context_namespace
    end

    def build_scope(base, query, opts = {})
      Scope.new(base, self, query, opts)
    end

    def base_scope
      adapter.base_scope(model)
    end

    def typecast(name, value, flag)
      att = get_attr!(name, flag, request: true)
      type_name = att[:type]
      if flag == :filterable
        type_name = filters[name][:type]
      end
      type = Graphiti::Types[type_name]
      return if value.nil? && type[:kind] != "array"
      begin
        flag = :read if flag == :readable
        flag = :write if flag == :writable
        flag = :params if [:sortable, :filterable].include?(flag)
        type[flag][value]
      rescue => e
        raise Errors::TypecastFailed.new(self, name, value, e, type_name)
      end
    end

    def associate_all(parent, children, association_name, type)
      adapter.associate_all(parent, children, association_name, type)
    end

    def associate(parent, child, association_name, type)
      adapter.associate(parent, child, association_name, type)
    end

    def disassociate(parent, child, association_name, type)
      adapter.disassociate(parent, child, association_name, type)
    end

    def assign_with_relationships(meta, attributes, relationships, caller_model = nil, foreign_key = nil)
      persistence = Graphiti::Util::Persistence \
        .new(self, meta, attributes, relationships, caller_model, foreign_key)
      persistence.assign
    end

    def persist_with_relationships(meta, attributes, relationships, caller_model = nil, foreign_key = nil)
      persistence = Graphiti::Util::Persistence \
        .new(self, meta, attributes, relationships, caller_model, foreign_key)
      persistence.run
    end

    def stat(attribute, calculation)
      stats_dsl = stats[attribute] || stats[attribute.to_sym]
      raise Errors::StatNotFound.new(attribute, calculation) unless stats_dsl
      stats_dsl.calculation(calculation)
    end

    def before_resolve(scope, query)
      scope
    end

    def resolve(scope)
      adapter.resolve(scope)
    end

    def after_graph_persist(model, metadata)
      hooks = self.class.config[:after_graph_persist][metadata[:method]] || []
      hooks.each do |hook|
        instance_exec(model, metadata, &hook)
      end
    end

    def before_commit(model, metadata)
      hooks = self.class.config[:before_commit][metadata[:method]] || []
      hooks.each do |hook|
        instance_exec(model, metadata, &hook)
      end
    end

    def after_commit(model, metadata)
      hooks = self.class.config[:after_commit][metadata[:method]] || []
      hooks.each do |hook|
        instance_exec(model, metadata, &hook)
      end
    end

    def transaction
      response = nil
      begin
        adapter.transaction(model) do
          response = yield
        end
      rescue Errors::ValidationError => e
        response = {result: e.validation_response}
      end
      response
    end

    def links?
      self.class.links.any?
    end

    def links(model)
      self.class.links.each_with_object({}) do |(name, blk), memo|
        memo[name] = instance_exec(model, &blk)
      end
    end
  end
end
