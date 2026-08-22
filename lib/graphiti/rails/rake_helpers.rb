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

      # The pool and RAILS_MAX_THREADS are read from this environment, and production may size both differently.
      def connection_pool_advisory
        return unless defined?(ActiveRecord::Base)

        pool = ActiveRecord::Base.connection_db_config.pool
        threads = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
        sideload_threads = Graphiti.config.concurrency_max_threads
        needed = threads + sideload_threads + 1
        return if pool.nil? || pool >= needed

        "WARNING database.yml pool is #{pool} in this environment. With concurrency on (the production default), " \
          "each sideload holds its own connection, so pool should be at least " \
          "web threads (#{threads}) + concurrency_max_threads (#{sideload_threads}) + 1 = #{needed}. " \
          "If production sizes these differently, check the numbers there. " \
          "See graphiti.dev/concepts/resources#concurrency-pool-sizing."
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
