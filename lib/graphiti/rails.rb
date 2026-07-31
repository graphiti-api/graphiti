require "graphiti"
require "rails"

module Graphiti
  # Rails integration for Graphiti. See {file:README.md} for more details.
  module Rails
    autoload :Context, "graphiti/rails/context"
    autoload :Controller, "graphiti/rails/controller"
    autoload :Debugging, "graphiti/rails/debugging"
    autoload :Responders, "graphiti/rails/responders"

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
