module Graphiti
  class Runner
    attr_reader :params
    attr_reader :deserialized_payload

    def initialize(resource_class, params, query = nil, action = nil)
      @resource_class = resource_class
      @params = params
      @query = query
      @action = action

      validator = RequestValidator.new(jsonapi_resource, params, action)
      validator.validate!

      @deserialized_payload = validator.deserialized_payload
    end

    def jsonapi_resource
      @jsonapi_resource ||= @resource_class.new
    end

    # Typically, this is 'self' of a controller
    # We're overriding here so we can do stuff like
    #
    # Graphiti.with_context my_context, {} do
    #   Runner.new ...
    # end
    def jsonapi_context
      Graphiti.context[:object]
    end

    def query
      @query ||= Query.new(jsonapi_resource, params, nil, nil, [], @action)
    end

    def query_hash
      @query_hash ||= query.hash
    end

    def wrap_context
      Graphiti.with_context(jsonapi_context, action_name.to_sym) do
        yield
      end
    end

    def jsonapi_scope(scope, opts = {})
      jsonapi_resource.build_scope(scope, query, opts)
    end

    def jsonapi_render_options
      options = {}
      options.merge!(default_jsonapi_render_options)
      options[:meta] ||= {}
      options[:expose] ||= {}
      options[:expose][:context] = jsonapi_context
      options
    end

    def proxy(base = nil, opts = {})
      base ||= jsonapi_resource.base_scope
      scope_opts = opts.slice(
        :sideload_parent_length,
        :default_paginate,
        :after_resolve,
        :sideload,
        :parent,
        :params,
        :bypass_required_filters
      )

      scope = jsonapi_scope(base, scope_opts)

      ::Graphiti::ResourceProxy.new(
        jsonapi_resource,
        scope,
        query,
        payload: deserialized_payload,
        single: opts[:single],
        raise_on_missing: opts[:raise_on_missing],
        cache: opts[:cache],
        cache_expires_in: opts[:cache_expires_in],
        cache_tag: opts[:cache_tag]
      )
    end
  end
end
