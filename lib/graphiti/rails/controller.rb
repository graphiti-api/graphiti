module Graphiti
  module Rails
    # Everything a controller needs to serve Graphiti resources. Include it in
    # the controller your API inherits from:
    #
    #   class ApplicationController < ActionController::Base
    #     include Graphiti::Rails::Controller
    #   end
    #
    # Graphiti applied all of this to every controller in the application until
    # 2.0, which meant wrapping unrelated actions in a Graphiti context and
    # registering a catch-all exception handler on controllers that never touch
    # Graphiti. Scoping it is now up to you.
    module Controller
      extend ActiveSupport::Concern

      included do
        include Graphiti::Rails::Context
        include Graphiti::Rails::Debugging
        # ActionController::API strips this out, but Graphiti serves multiple
        # formats (jsonapi/json/xml), so respond_to has to work everywhere.
        include ActionController::MimeResponds

        # Broad, but the handler only renders formats listed in
        # config.graphiti.handled_exception_formats and hands everything else
        # back to Rails.
        register_exception Exception,
          status: :passthrough,
          handler: Graphiti::Rails::FallbackHandler

        register_exception Graphiti::Errors::InvalidRequest,
          status: 400, handler: Graphiti::Rails::InvalidRequestHandler
        register_exception Graphiti::Errors::ConflictRequest,
          status: 409, handler: Graphiti::Rails::ConflictRequestHandler
        register_exception Graphiti::Errors::RecordNotFound,
          status: 404, handler: Graphiti::Rails::ExceptionHandler
        register_exception Graphiti::Errors::RemoteWrite,
          status: 400, handler: Graphiti::Rails::ExceptionHandler
        register_exception Graphiti::Errors::SingularSideload,
          status: 400, handler: Graphiti::Rails::ExceptionHandler
      end
    end
  end
end
