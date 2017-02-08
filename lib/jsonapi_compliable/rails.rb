require 'jsonapi/rails'

module JsonapiCompliable
  module Rails
    def self.included(klass)
      klass.send(:include, Base)

      klass.class_eval do
        around_action :wrap_context
        alias_method :perform_render_jsonapi, :render
      end
    end
  end
end
