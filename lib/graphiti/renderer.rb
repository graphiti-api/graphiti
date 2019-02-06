module Graphiti
  class Renderer
    CONTENT_TYPE = 'application/vnd.api+json'

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

    def to_json
      render(self.class.hash_renderer(@proxy)).to_json
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

    private

    def render(renderer)
      Graphiti.broadcast(:render, records: records, options: options) do
        options[:fields] = proxy.fields
        options[:expose] ||= {}
        options[:expose][:extra_fields] = proxy.extra_fields
        options[:expose][:proxy] = proxy
        options[:include] = proxy.include_hash
        options[:links] = proxy.pagination.links if proxy.pagination.links?
        options[:meta] ||= {}
        options[:meta].merge!(stats: proxy.stats) unless proxy.stats.empty?
        options[:meta][:debug] = Debugger.to_a if debug_json?

        renderer.render(records, options)
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
