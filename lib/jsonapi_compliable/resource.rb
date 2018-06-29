module JsonapiCompliable
  class Resource
    include DSL
    include Configuration
    include Sideloading

    attr_reader :context

    def around_scoping(scope, query_hash)
      yield scope
    end

    def serializer_for(model)
      serializer
    end

    def with_context(object, namespace = nil)
      JsonapiCompliable.with_context(object, namespace) do
        yield
      end
    end

    def context
      JsonapiCompliable.context[:object]
    end

    def context_namespace
      JsonapiCompliable.context[:namespace]
    end

    # external facing; does not accept internal-specific options
    def self.all(params = {}, base_scope = nil)
      _all(params, {}, base_scope)
    end

    def self._all(params, opts, base_scope)
      runner = Runner.new(self, params)
      runner.proxy(base_scope, opts)
    end

    def self.find(params, base_scope = nil)
      params[:filter] ||= {}
      params[:filter].merge!(id: params.delete(:id))
      runner = Runner.new(self, params)
      runner.proxy(base_scope, single: true)
    end

    def build_scope(base, query, opts = {})
      Scope.new(base, self, query, opts)
    end

    def base_scope
      adapter.base_scope(model)
    end

    def create(create_params)
      adapter.create(model, create_params)
    end

    def update(update_params)
      adapter.update(model, update_params)
    end

    def destroy(id)
      adapter.destroy(model, id)
    end

    def associate(parent, child, association_name, type)
      adapter.associate(parent, child, association_name, type)
    end

    def disassociate(parent, child, association_name, type)
      adapter.disassociate(parent, child, association_name, type)
    end

    def persist_with_relationships(meta, attributes, relationships, caller_model = nil)
      persistence = JsonapiCompliable::Util::Persistence \
        .new(self, meta, attributes, relationships, caller_model)
      persistence.run
    end

    def stat(attribute, calculation)
      stats_dsl = stats[attribute] || stats[attribute.to_sym]
      raise Errors::StatNotFound.new(attribute, calculation) unless stats_dsl
      stats_dsl.calculation(calculation)
    end

    def resolve(scope)
      adapter.resolve(scope)
    end

    def before_commit(model, method)
      hook = self.class.config[:before_commit][method]
      hook.call(model) if hook
    end

    def transaction
      response = nil
      begin
        adapter.transaction(model) do
          response = yield
        end
      rescue Errors::ValidationError => e
        response = e.validation_response
      end
      response
    end
  end
end
