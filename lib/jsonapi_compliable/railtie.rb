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
      register_renderers
    end

    def register_renderers
      ActiveSupport.on_load(:action_controller) do
        ::ActionController::Renderers.add(:jsonapi) do |proxy, options|
          self.content_type ||= Mime[:jsonapi]

          opts = {}
          if respond_to?(:default_jsonapi_render_options)
            opts = default_jsonapi_render_options
          end
          proxy.to_jsonapi(options)
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
  end
end
