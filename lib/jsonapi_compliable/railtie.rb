require 'rails/railtie'
require 'action_controller'
require 'action_controller/railtie'
require 'action_controller/serialization'

module ActiveModelSerializers
  class Railtie < Rails::Railtie
    initializer 'jsonapi_compliable.register_renderer' do
      require 'active_model_serializers/register_jsonapi_renderer'
    end

    initializer 'jsonapi_compliable.configure_ams' do
      if ActiveModelSerializers.config.respond_to?(:include_data_default)
        ActiveModelSerializers.config.include_data_default = :if_sideloaded
      end
    end
  end
end
