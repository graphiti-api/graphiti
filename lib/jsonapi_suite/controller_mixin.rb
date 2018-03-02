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
        include JsonapiSuite::StrongResources::ControllerMixin
      end
    end
  end
end
