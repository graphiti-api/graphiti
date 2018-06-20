module JsonapiCompliable
  class Resource
    include DSL
    include Configuration
    include Sideloading

    attr_reader :context

    def around_scoping(scope, query_hash)
      yield scope
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

    # return single/raise if not found
    # EmployeeResource.find(params)
    #
    # return single/DONT raise if not found
    #
    # return multiple
    # EmployeeResource.all(params) # base_scope if needed
    #
    # posts = EmployeeResource.query(params)
    # render jsonapi: posts
    #
    # maybe
    # EmployeeResource.create(params)
    # EmployeeResource.update(params)
    # EmployeeResource.destroy(params)
    def self.all(params, base_scope = nil)
      runner = Runner.new(self, params)
      # todo resource base scope
      runner.resolve(base_scope || model.all)
    end

    def self.find(params, base_scope = nil)
      params[:filter] ||= {}
      params[:filter].merge!(id: params[:id])
      runner = Runner.new(self, params)
      # todo resource base scope
      runner.resolve(base_scope || model.all, single: true)
    end

    def build_scope(base, query, opts = {})
      Scope.new(base, self, query, opts)
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
