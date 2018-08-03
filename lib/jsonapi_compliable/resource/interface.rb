module JsonapiCompliable
  class Resource
    module Interface
      extend ActiveSupport::Concern

      class_methods do
        def all(params = {}, base_scope = nil)
          validate!
          _all(params, {}, base_scope)
        end

        # @api private
        def _all(params, opts, base_scope)
          runner = Runner.new(self, params)
          runner.proxy(base_scope, opts)
        end

        def find(params, base_scope = nil)
          validate!
          id = params[:data].try(:[], :id) || params.delete(:id)
          params[:filter] ||= {}
          params[:filter].merge!(id: id)

          runner = Runner.new(self, params)
          runner.proxy(base_scope, single: true, raise_on_missing: true)
        end

        def build(params, base_scope = nil)
          validate!
          runner = Runner.new(self, params)
          runner.proxy(base_scope, single: true, raise_on_missing: true)
        end

        private

        def validate!
          if context && context.respond_to?(:request)
            path = context.request.env['PATH_INFO']
            unless allow_request?(path, context_namespace)
              raise Errors::InvalidEndpoint.new(self, path, context_namespace)
            end
          end
        end
      end
    end
  end
end
