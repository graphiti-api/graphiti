module Graphiti
  module Rails
    # Wrap a request in `handle_request_exceptions` to assert on the rendered
    # error payload. Exceptions propagate untouched in tests otherwise.
    module TestHelpers
      include RescueRegistry::RailsTestHelpers

      # rescue_registry sets action_dispatch.show_exceptions to true/false.
      # Rails 7.1 replaced those with :all/:rescuable/:none, and Rails 8 dropped
      # boolean handling altogether. ExceptionWrapper#show? now treats
      # everything that is not :none as "show", so passing false would leave
      # exception handling on and silently do nothing.
      def handle_request_exceptions(handle = true, &block)
        super(handle ? :all : :none, &block)
      end

      def handle_request_exceptions?
        ::Rails.application.config.action_dispatch.show_exceptions != :none
      end
    end
  end
end
