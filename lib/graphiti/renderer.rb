module Graphiti
  class Renderer
    CONTENT_TYPE = "application/vnd.api+json"

    attr_reader :proxy, :options

    def initialize(proxy, options)
      @proxy = proxy
      @options = options
    end

    def records
      @records ||= @proxy.data
    end

    def to_jsonapi
      render(self.class.jsonapi_renderer).to_json
    end

    def as_graphql
      render(self.class.graphql_renderer(@proxy))
    end

    def to_graphql
      as_graphql.to_json
    end

    def to_json
      as_json.to_json
    end

    def as_json
      render(self.class.hash_renderer(@proxy))
    end

    def to_xml
      render(self.class.hash_renderer(@proxy)).to_xml(root: :data)
    end

    def self.jsonapi_renderer
      @jsonapi_renderer ||= JSONAPI::Serializable::Renderer
        .new(JSONAPI::Renderer.new)
    end

    def self.hash_renderer(proxy)
      implementation = Graphiti::HashRenderer.new(proxy.resource)
      JSONAPI::Serializable::Renderer.new(implementation)
    end

    def self.graphql_renderer(proxy)
      implementation = Graphiti::HashRenderer.new(proxy.resource, graphql: true)
      JSONAPI::Serializable::Renderer.new(implementation)
    end

    private

    def render(renderer)
      Graphiti.broadcast(:render, records: records, proxy: proxy, options: options) do
        # TODO: If these aren't expensive to compute, set them before the broadcast block
        options[:fields] = proxy.fields
        options[:expose] ||= {}
        options[:expose][:extra_fields] = proxy.extra_fields
        options[:expose][:proxy] = proxy
        options[:include] = proxy.include_hash
        options[:links] = proxy.pagination.links if proxy.pagination.links?
        options[:meta] ||= proxy.meta
        options[:meta][:stats] = proxy.stats unless proxy.stats.empty?
        options[:meta][:debug] = Debugger.to_a if debug_json?
        options[:proxy] = proxy

        if proxy.cache?
          Graphiti.cache("#{proxy.cache_key}/render", version: proxy.updated_at, expires_in: proxy.cache_expires_in) do
            options.delete(:cache) # ensure that we don't use JSONAPI-Resources's built-in caching logic
            renderer.render(records, options)
          end
        else
          renderer.render(records, options)
        end
      end
    end

    def debug_json?
      debug = false
      if Debugger.enabled && proxy.debug_requested?
        context = proxy.resource.context
        if context.respond_to?(:allow_graphiti_debug_json?)
          debug = context.allow_graphiti_debug_json?
        end
      end
      debug
    end
  end
end
