require "rescue_registry"
require "graphiti"
require "rails"

module Graphiti
  # Rails integration for Graphiti. See {file:README.md} for more details.
  module Rails
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
end

ActiveSupport.on_load(:active_record) do
  require "graphiti/adapters/active_record"
end

require "graphiti/rails/railtie"
