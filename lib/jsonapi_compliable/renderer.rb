module JsonapiCompliable
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
      notify do
        instance = JSONAPI::Serializable::Renderer.new

        if proxy.is_a?(PersistenceProxy)
          options[:include] = proxy.payload.include_directive
        else
          options[:fields] = proxy.query.fields
          options[:expose][:extra_fields] = proxy.query.extra_fields
          options[:include] = proxy.query.include_hash
          options[:meta].merge!(stats: proxy.stats) unless proxy.stats.empty?
        end
        instance.render(records, options).to_json
      end
    end

    private

    # TODO: more generic notification pattern
    # Likely comes out of debugger work
    def notify
      if defined?(ActiveSupport::Notifications)
        opts = [
          'render.jsonapi-compliable',
          records: records,
          options: options
        ]
        ActiveSupport::Notifications.instrument(*opts) do
          yield
        end
      else
        yield
      end
    end
  end
end
