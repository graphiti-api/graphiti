module Graphiti
  # Rails Integration. Mix this in to ApplicationController.
  #
  # * Mixes in Base
  # * Adds a global around_action (see Base#wrap_context)
  #
  # @see Base#render_jsonapi
  # @see Base#wrap_context
  module Rails
    def self.included(klass)
      klass.class_eval do
        include Graphiti::Context
        include GraphitiErrors
        around_action :wrap_context
        around_action :debug
      end
    end

    def wrap_context
      Graphiti.with_context(jsonapi_context, action_name.to_sym) do
        yield
      end
    end

    def debug
      Debugger.debug do
        yield
      end
    end

    def jsonapi_context
      self
    end
  end
end
