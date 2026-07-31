module Graphiti
  module Rails
    # Wraps controller actions in a [Graphiti Debugger](https://www.graphiti.dev/guides/concepts/debugging#debugger).
    module Debugging
      def self.included(klass)
        klass.around_action :debug_graphiti
      end

      # Called by [`#around_action`](https://api.rubyonrails.org/classes/AbstractController/Callbacks/ClassMethods.html#method-i-around_action)
      # to wrap the current action in a Graphiti Debugger.
      def debug_graphiti
        Debugger.debug do
          yield
        end
      end
    end
  end
end
