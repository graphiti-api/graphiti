module Graphiti
  class Resource
    module Interface
      extend ActiveSupport::Concern

      class_methods do
        def cache_resource(expires_in: false, tag: nil)
          @cache_resource = true
          @cache_expires_in = expires_in
          @cache_tag = tag
        end

        def all(params = {}, base_scope = nil)
          validate_request!(params)
          _all(params, {}, base_scope)
        end

        # @api private
        def _all(params, opts, base_scope)
          runner = Runner.new(self, params, opts.delete(:query), :all)
          opts[:params] = params
          runner.proxy(base_scope, opts.merge(caching_options))
        end

        def find(params = {}, base_scope = nil)
          validate_request!(params)
          _find(params, base_scope)
        end

        # @api private
        def _find(params = {}, base_scope = nil)
          guard_nil_id!(params[:data])
          guard_nil_id!(params)

          id = params[:data].try(:[], :id) || params.delete(:id)
          params[:filter] ||= {}
          params[:filter][:id] = id if id

          runner = Runner.new(self, params, nil, :find)

          find_options = {
            single: true,
            raise_on_missing: true,
            bypass_required_filters: true
          }.merge(caching_options)

          runner.proxy base_scope, find_options
        end

        def build(params, base_scope = nil)
          validate_request!(params)
          runner = Runner.new(self, params)
          runner.proxy(base_scope, single: true, raise_on_missing: true).tap do |instance|
            instance.assign_attributes(params) # assign the params to the underlying model
          end
        end

        def load(models, base_scope = nil)
          runner = Runner.new(self, {}, base_scope, :find)
          runner.proxy(nil, bypass_required_filters: true).tap do |r|
            r.data = models
          end
        end

        private

        def caching_options
          {cache: @cache_resource, cache_expires_in: @cache_expires_in, cache_tag: @cache_tag}
        end

        def validate_request!(params)
          return if Graphiti.context[:graphql] || !validate_endpoints?

          if context&.respond_to?(:request)
            path = context.request.env["PATH_INFO"]
            unless allow_request?(path, params, context_namespace)
              raise Errors::InvalidEndpoint.new(self, path, context_namespace)
            end
          end
        end

        def guard_nil_id!(params)
          return unless params
          if params.key?(:id) && params[:id].nil?
            raise Errors::UndefinedIDLookup.new(self)
          end
        end
      end
    end
  end
end
