require "rescue_registry"
require "graphiti"
require "rails"

module Graphiti
  # Rails integration for Graphiti. See {file:README.md} for more details.
  module Rails
    # Graphiti::Rails was a controller mixin before it became this namespace.
    # Including a namespace is not an error, it just does nothing, so honour
    # the old spelling rather than leave a controller silently without its
    # context, debugger and exception handlers.
    def self.included(klass)
      DEPRECATOR.deprecation_warning(
        "Including Graphiti::Rails",
        "include Graphiti::Rails::Controller instead"
      )

      klass.include(Controller)
    end

    # graphiti-rails had its own, and apps that silenced it by name still resolve.
    DEPRECATOR = Graphiti::DEPRECATOR

    autoload :ConflictRequestHandler, "graphiti/rails/exception_handlers"
    autoload :Context, "graphiti/rails/context"
    autoload :Controller, "graphiti/rails/controller"
    autoload :Debugging, "graphiti/rails/debugging"
    autoload :ExceptionHandler, "graphiti/rails/exception_handlers"
    autoload :FallbackHandler, "graphiti/rails/exception_handlers"
    autoload :InvalidRequestHandler, "graphiti/rails/exception_handlers"
    autoload :Responders, "graphiti/rails/responders"
    autoload :TestHelpers, "graphiti/rails/test_helpers"

    # @!attribute self.handled_exception_formats
    # A list of formats as symbols whose exceptions will be handled by Graphiti. See {Railtie}.
    cattr_accessor :handled_exception_formats, default: []

    # @!attribute self.respond_to_formats
    # A list of formats as symbols which will be available for Graphiti::Rails::Responders. See {Railtie}.
    cattr_accessor :respond_to_formats, default: []
  end

  # Deprecated. Was core's own responders mixin, superseded by the one that came
  # in with graphiti-rails. Remove in 3.0.
  Responders = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(
    "Graphiti::Responders",
    "Graphiti::Rails::Responders",
    DEPRECATOR
  )
end

ActiveSupport.on_load(:active_record) do
  require "graphiti/adapters/active_record"
end

require "graphiti/rails/railtie"
