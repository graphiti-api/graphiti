module JsonapiSuite
  module ControllerMixin
    def self.included(klass)
      klass.class_eval do
        if defined?(Rails)
          include JsonapiCompliable::Rails
        else
          include JsonapiCompliable::Base
        end
        include JsonapiErrorable
        include StrongResources::Controller::Mixin
      end
    end
  end
end
