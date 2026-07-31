module Graphiti
  module Rails
    # Wraps controller actions in a [Graphiti Context](https://www.graphiti.dev/guides/concepts/resources#context) which points to the
    # controller instance by default.
    module Context
      def self.included(klass)
        klass.class_eval do
          include Graphiti::Context
          around_action :wrap_graphiti_context
        end
      end

      # Called by [`#around_action`](https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-around_action)
      # to wrap the current action in a Graphiti context defined by {#graphiti_context}.
      def wrap_graphiti_context
        Graphiti.with_context(graphiti_context, action_name.to_sym) do
          yield
        end
      end

      # The context to use for Graphiti Resources. Defaults to the controller instance.
      # Can be redefined for different behavior.
      def graphiti_context
        if respond_to?(:jsonapi_context)
          DEPRECATOR.deprecation_warning("Overriding jsonapi_context", "Override #graphiti_context instead")
          jsonapi_context
        else
          self
        end
      end
    end
  end
end
