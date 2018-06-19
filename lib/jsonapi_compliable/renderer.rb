module JsonapiCompliable
  class Renderer
    CONTENT_TYPE = 'application/vnd.api+json'

    attr_reader :records, :options

    def initialize(records, options)
      @records = records
      @options = options
    end

    def to_jsonapi
      notify do
        instance = JSONAPI::Serializable::Renderer.new
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
