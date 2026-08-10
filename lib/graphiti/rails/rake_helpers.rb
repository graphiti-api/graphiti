require "graphiti/rails/test_helpers"

module Graphiti
  module Rails
    # Rake's `namespace` takes a block, and a block does not open a new definee,
    # so helpers defined inside one are defined on Object and turn up in every
    # request spec in the host app. They live here to stay off that namespace.
    module RakeHelpers
      extend TestHelpers

      module_function

      # ::Rails throughout, because bare Rails resolves to Graphiti::Rails here.
      def session
        @session ||= ActionDispatch::Integration::Session.new(::Rails.application)
      end

      def setup_rails!
        ::Rails.application.eager_load!
        ::Rails.application.config.cache_classes = true
        ::Rails.application.config.action_controller.perform_caching = false
      end

      def make_request(path, debug = false)
        if path.split("/").length == 2
          path = "#{ApplicationResource.endpoint_namespace}#{path}"
        end
        path << if path.include?("?")
          "&cache=bust"
        else
          "?cache=bust"
        end
        path = "#{path}&debug=true" if debug
        handle_request_exceptions do
          headers = {Authorization: ENV["AUTHORIZATION_HEADER"]}.compact
          session.get(path.to_s, headers: headers)
        end
        JSON.parse(session.response.body)
      end
    end
  end
end
