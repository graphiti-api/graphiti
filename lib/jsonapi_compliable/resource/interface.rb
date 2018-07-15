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
          id = params[:data].try(:[], :id) || params.delete(:id)
          params[:filter] ||= {}
          params[:filter].merge!(id: id)

          runner = Runner.new(self, params)
          runner.proxy(base_scope, single: true, raise_on_missing: true)
        end

        def build(params, base_scope = nil)
          runner = Runner.new(self, params)
          runner.proxy(base_scope, single: true, raise_on_missing: true)
        end
      end
    end
  end
end
