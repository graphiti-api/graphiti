module Graphiti
  module Util
    class TransactionHooksRecorder
      # This is a thread-global singleton class which is used to capture
      # the correct hooks to run when before and after transactions are
      # committed.  Consuming code will call the #record method, which will
      # yield to the passed block:
      #
      # ```ruby
      # TransactionHooksRecorder.record do
      #   TransactionHooksRecorder.add(->{ do_stuff() }, :before_commit)
      #   TransactionHooksRecorder.add(->{ do_more_stuff() }, :after_commit)
      #   {
      #     result: do_the_main_thing_and_return_a_result()
      #   }
      # end
      # ```
      #
      # before_commit hooks will be executed before the record method returns.
      # All after_commit hooks will be added to the returned hash so that consumers
      # can decide when and whether to execute the callbacks.
      #
      # Returns a hash with `result` and `after_commit_hooks` keys.
      class << self
        def record
          reset_hooks

          begin
            result = yield
            run(:before_commit)

            unless result.is_a?(::Hash)
              result = {result: result}
            end

            result.tap do |r|
              r[:after_commit_hooks] = hook_set(:after_commit)
            end
          ensure
            reset_hooks
          end
        end

        def run_graph_persist_hooks
          run(:after_graph_persist)
        end

        # Because hooks will be added from the outer edges of
        # the graph, working inwards
        def add(prc, lifecycle_event)
          hook_set(lifecycle_event).unshift(prc)
        end

        def run(lifecycle_event)
          _hooks[lifecycle_event].each { |h| h.call }
        end

        private

        def _hooks
          Thread.current[:_graphiti_hooks]
        end

        def reset_hooks
          Thread.current[:_graphiti_hooks] = {
            after_graph_persist: [],
            before_commit: [],
            after_commit: []
          }
        end

        def hook_set(lifecycle_event)
          _hooks[lifecycle_event]
        end
      end
    end
  end
end
