module JsonapiCompliable
  class Railtie < ::Rails::Railtie
    initializer "jsonapi_compliable.require_activerecord_adapter" do
      config.after_initialize do |app|
        ActiveSupport.on_load(:active_record) do
          require 'jsonapi_compliable/adapters/active_record'
        end
      end
    end

    initializer 'jsonapi_compliable.init' do
      if Mime[:jsonapi].nil? # rails 4
        Mime::Type.register('application/vnd.api+json', :jsonapi)
      end
      register_parameter_parser
      register_renderers
      establish_concurrency
      configure_endpoint_lookup
    end

    # from jsonapi-rails
    PARSER = lambda do |body|
      data = JSON.parse(body)
      data[:format] = :jsonapi
      data.with_indifferent_access
    end

    def register_parameter_parser
      if ::Rails::VERSION::MAJOR >= 5
        ActionDispatch::Request.parameter_parsers[:jsonapi] = PARSER
      else
        ActionDispatch::ParamsParser::DEFAULT_PARSERS[Mime[:jsonapi]] = PARSER
      end
    end

    def register_renderers
      ActiveSupport.on_load(:action_controller) do
        ::ActionController::Renderers.add(:jsonapi) do |proxy, options|
          self.content_type ||= Mime[:jsonapi]

          opts = {}
          if respond_to?(:default_jsonapi_render_options)
            opts = default_jsonapi_render_options
          end

          if proxy.is_a?(Hash) # for destroy
            render(options.merge(json: proxy))
          else
            proxy.to_jsonapi(options)
          end
        end
      end

      ActiveSupport.on_load(:action_controller) do
        ::ActionController::Renderers.add(:jsonapi_errors) do |proxy, options|
          self.content_type ||= Mime[:jsonapi]

          validation = JsonapiErrorable::Serializers::Validation.new \
            proxy.data, proxy.payload.relationships

          render \
            json: { errors: validation.errors },
            status: :unprocessable_entity
        end
      end
    end

    # Only run concurrently if our environment supports it
    def establish_concurrency
      JsonapiCompliable.config.concurrency = !::Rails.env.test? &&
        ::Rails.application.config.cache_classes
    end

    def configure_endpoint_lookup
      JsonapiCompliable.config.context_for_endpoint = ->(path, action) {
        method = :GET
        case action
          when :show then path = "#{path}/1"
          when :create then method = :POST
          when :update
            path = "#{path}/1"
            method = :PUT
          when :destroy
            path = "#{path}/1"
            method = :DELETE
        end

        route = ::Rails.application.routes.recognize_path(path, method: method) rescue nil
        "#{route[:controller]}_controller".classify.safe_constantize if route
      }
    end
  end
end
