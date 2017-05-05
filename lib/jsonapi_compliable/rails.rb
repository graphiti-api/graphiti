require 'jsonapi/rails'

module JsonapiCompliable
  # Rails Integration. Mix this in to ApplicationController.
  #
  # * Mixes in Base
  # * Adds a global around_action (see Base#wrap_context)
  # * Uses Rails' +render+ for rendering
  #
  # @see Base#render_jsonapi
  # @see Base#wrap_context
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
