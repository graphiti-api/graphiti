module JsonapiSuite
  module ControllerMixin
    def self.included(klass)
      klass.class_eval do
        include JSONAPICompliable
        include JsonapiErrorable
        include StrongResources::Controller::Mixin
      end
    end
  end
end
