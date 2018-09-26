module Graphiti
  module Base
    extend ActiveSupport::Concern

    def jsonapi_resource
      @jsonapi_resource
    end

    def query
      @query ||= Query.new(jsonapi_resource, params)
    end

    def query_hash
      @query_hash ||= query.hash
    end

    def wrap_context
      Graphiti.with_context(jsonapi_context, action_name.to_sym) do
        yield
      end
    end

    def jsonapi_context
      self
    end

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

    def deserialized_params
      @deserialized_params ||= begin
        payload = normalized_params
        if payload[:data] && payload[:data][:type]
          Graphiti::Deserializer.new(payload)
        end
      end
    end

    def jsonapi_render_options
      options = {}
      options.merge!(default_jsonapi_render_options)
      options[:meta]   ||= {}
      options[:expose] ||= {}
      options[:expose][:context] = jsonapi_context
      options
    end

    def proxy(base = nil, opts = {})
      base ||= jsonapi_resource.base_scope
      scope_opts = opts.slice :sideload_parent_length,
        :default_paginate,
        :after_resolve,
        :sideload,
        :parent,
        :params
      scope = jsonapi_scope(base, scope_opts)
      ResourceProxy.new jsonapi_resource,
        scope,
        query,
        payload: deserialized_params,
        single: opts[:single],
        raise_on_missing: opts[:raise_on_missing]
    end
  end
end
