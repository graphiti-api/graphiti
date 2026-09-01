# frozen_string_literal: true

module Graphiti
  module Rails
    # This Railtie exposes some configuration options:
    # * `config.graphiti.handled_exception_formats`, defaulting to `[:jsonapi]`.
    #   Formats in this list will always have their exceptions handled by Graphiti.
    # * `config.graphiti.respond_to_formats`, defaulting to `[:json, :jsonapi, :xml]`.
    #   When {Graphiti::Rails::Responders} is included in a controller it will respond
    #   to these mime types by default.
    class Railtie < ::Rails::Railtie
      config.graphiti = ActiveSupport::OrderedOptions.new

      config.graphiti.handled_exception_formats = [:jsonapi]

      old_respond_to_formats = Graphiti::DEPRECATOR.silence { Graphiti.config.try(:respond_to) }
      config.graphiti.respond_to_formats = old_respond_to_formats || [:json, :jsonapi, :xml]

      rake_tasks do
        load File.expand_path("../../tasks/graphiti.rake", __dir__)
      end

      # ActionDispatch has already copied config.action_dispatch.rescue_responses into the wrapper by now.
      initializer "graphiti-rails.rescue_responses", after: "action_dispatch.configure" do
        responses = ActionDispatch::ExceptionWrapper.rescue_responses

        Graphiti::Rails::CLIENT_ERROR_STATUSES.each do |exception, status|
          # rescue_responses answers :internal_server_error for a missing key, so ||= never assigns.
          responses[exception] = status unless responses.key?(exception)
        end
      end

      initializer "graphiti-rails.config" do |app|
        Graphiti::Rails.handled_exception_formats = app.config.graphiti.handled_exception_formats
        Graphiti::Rails.respond_to_formats = app.config.graphiti.respond_to_formats

        root = ::Rails.root

        config_file = root.join(".graphiticfg.yml")
        if config_file.exist?
          cfg = YAML.load_file(config_file)
          Graphiti.config.schema_path = root.join("public#{cfg["namespace"]}/schema.json")
        else
          Graphiti.config.schema_path = root.join("public/schema.json")
        end
      end

      initializer "graphti-rails.logger" do
        config.after_initialize do
          Graphiti.config.debug = ::Rails.logger.debug? && Graphiti.config.debug
          Graphiti.logger = ::Rails.logger
        end
      end

      initializer "graphiti-rails.init" do
        if ::Rails.application.config.eager_load
          config.after_initialize do |app|
            ::Rails.application.reload_routes!
            Graphiti.setup!
          end
        end

        register_mime_type
        register_parameter_parser
        register_renderers
        establish_concurrency
        configure_endpoint_lookup
      end

      # from jsonapi-rails
      MEDIA_TYPE = "application/vnd.api+json"

      PARSER = lambda do |body|
        data = JSON.parse(body)
        data[:format] = :jsonapi
        data.with_indifferent_access
      end

      def register_mime_type
        Mime::Type.register(MEDIA_TYPE, :jsonapi) if Mime[:jsonapi].nil?
      end

      def register_parameter_parser
        ActionDispatch::Request.parameter_parsers[:jsonapi] ||= PARSER
      end

      def register_renderers
        ActiveSupport.on_load(:action_controller) do
          ::ActionController::Renderers.add(:jsonapi) do |proxy, options|
            self.content_type ||= Mime[:jsonapi]

            # opts = {}
            # if respond_to?(:default_jsonapi_render_options)
            #   opts = default_jsonapi_render_options
            # end

            if proxy.is_a?(Hash) # for destroy
              render(options.merge(json: proxy))
            else
              proxy.to_jsonapi(options)
            end
          end
        end

        ActiveSupport.on_load(:action_controller) do
          ActionController::Renderers.add(:jsonapi_errors) do |proxy, options|
            self.content_type ||= Mime[:jsonapi]

            validation = Graphiti::ErrorSerializers::Validation.new \
              proxy.data, proxy.payload.relationships

            render \
              json: {errors: validation.errors},
              status: :unprocessable_entity
          end
        end
      end

      # Only run concurrently if our environment supports it
      def establish_concurrency
        Graphiti.config.concurrency = !::Rails.env.test? &&
          ::Rails.application.config.cache_classes
      end

      def configure_endpoint_lookup
        Graphiti.config.context_for_endpoint = ->(path, action) {
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

          route = begin
            ::Rails.application.routes.recognize_path(path.to_s, method: method)
          rescue
            nil
          end
          "#{route[:controller]}_controller".classify.safe_constantize if route
        }
      end
    end
  end
end
