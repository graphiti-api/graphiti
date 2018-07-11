module JsonapiCompliable
  class Resource
    module Interface
      extend ActiveSupport::Concern

      class_methods do
        def all(params = {}, base_scope = nil)
          _all(params, {}, base_scope)
        end

        def _all(params, opts, base_scope)
          runner = Runner.new(self, params)
          runner.proxy(base_scope, opts)
        end

        def find(params, base_scope = nil)
          params[:filter] ||= {}
          params[:filter].merge!(id: params.delete(:id))

          runner = Runner.new(self, params)
          runner.proxy(base_scope, single: true)
        end

        def build(params)
          runner = Runner.new(self, params)
          runner.build
        end

        def create(params)
          runner = Runner.new(self, params)
          runner.jsonapi_create
        end
      end
    end
  end
end
