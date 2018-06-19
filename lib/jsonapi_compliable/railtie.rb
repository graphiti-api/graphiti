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
      register_renderer
    end

    def register_renderer
      ActiveSupport.on_load(:action_controller) do
        ::ActionController::Renderers.add(:jsonapi) do |records, options|
          self.content_type ||= Mime[:jsonapi]
          render_jsonapi(records, options)
        end
      end
    end
  end
end
