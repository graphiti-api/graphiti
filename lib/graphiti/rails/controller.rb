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
      end
    end
  end
end
