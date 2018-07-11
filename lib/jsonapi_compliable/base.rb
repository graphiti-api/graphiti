module JsonapiCompliable
  # Provides main interface to jsonapi_compliable
  #
  # This gets mixed in to a "context" class, such as a Rails controller.
  module Base
    extend ActiveSupport::Concern

    # Returns an instance of the associated Resource
    #
    # In other words, if you configured your controller as:
    #
    #   jsonapi resource: MyResource
    #
    # This returns MyResource.new
    #
    # @return [Resource] the configured Resource for this controller
    def jsonapi_resource
      @jsonapi_resource
    end

    # Instantiates the relevant Query object
    #
    # @see Query
    # @return [Query] the Query object for this resource/params
    def query
      @query ||= Query.new(jsonapi_resource, params)
    end

    # @see Query#to_hash
    # @return [Hash] the normalized query hash for only the *current* resource
    def query_hash
      @query_hash ||= query.to_hash
    end

    def wrap_context
      JsonapiCompliable.with_context(jsonapi_context, action_name.to_sym) do
        yield
      end
    end

    def jsonapi_context
      self
    end

    # Use when direct, low-level access to the scope is required.
    #
    # @example Show Action
    #   # Scope#resolve returns an array, but we only want to render
    #   # one object, not an array
    #   scope = jsonapi_scope(Employee.where(id: params[:id]))
    #   render_jsonapi(scope.resolve.first, scope: false)
    #
    # @example Scope Chaining
    #   # Chain onto scope after running through typical DSL
    #   # Here, we'll add active: true to our hash if the user
    #   # is filtering on something
    #   scope = jsonapi_scope({})
    #   scope.object.merge!(active: true) if scope.object[:filter]
    #
    # @see Resource#build_scope
    # @return [Scope] the configured scope
    def jsonapi_scope(scope, opts = {})
      jsonapi_resource.build_scope(scope, query, opts)
    end

    def normalized_params
      normalized = params
      if normalized.respond_to?(:to_unsafe_h)
        normalized = normalized.to_unsafe_h.deep_symbolize_keys
      end
      normalized
    end

    # @see Deserializer#initialize
    # @return [Deserializer]
    def deserialized_params
      @deserialized_params ||= JsonapiCompliable::Deserializer.new(normalized_params)
    end

    def persisting?
      [:create, :update, :destroy].include?(JsonapiCompliable.context[:namespace])
    end

    def jsonapi_render_options
      options = {}
      options.merge!(default_jsonapi_render_options)
      options[:meta]   ||= {}
      options[:expose] ||= {}
      options[:expose][:context] = jsonapi_context
      options
    end

    def build
      PersistenceProxy.new(jsonapi_resource, deserialized_params)
    end

    def proxy(base = nil, opts = {})
      if persisting?
        PersistenceProxy.new(jsonapi_resource, deserialized_params)
      else
        base       ||= jsonapi_resource.base_scope
        scope_opts   = opts.slice(:sideload_parent_length, :default_paginate, :after_resolve)
        scope = jsonapi_scope(base, scope_opts)
        !!opts[:single] ? SingleResourceProxy : ResourceProxy
        proxy_class  = !!opts[:single] ? SingleResourceProxy : ResourceProxy
        proxy_class.new(jsonapi_resource, scope, query)
      end
    end
  end
end
