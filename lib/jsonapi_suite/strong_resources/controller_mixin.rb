module JsonapiSuite
  module StrongResources
    module ControllerMixin
      extend ActiveSupport::Concern

      included do
        include ::StrongResources::Controller::Mixin

        register_exception StrongerParameters::InvalidParameter,
          handler: StrongerParametersExceptionHandler
      end
    end
  end
end
