module JsonapiCompliable
  module Util
    class Hooks
      def self.record
        self.hooks = []
        begin
          yield.tap { run }
        ensure
          self.hooks = []
        end
      end

      def self._hooks
        Thread.current[:_compliable_hooks] ||= []
      end
      private_class_method :_hooks

      def self.hooks=(val)
        Thread.current[:_compliable_hooks] = val
      end

      # Because hooks will be added from the outer edges of
      # the graph, working inwards
      def self.add(prc)
        _hooks.unshift(prc)
      end

      def self.run
        _hooks.each { |h| h.call }
      end
    end
  end
end
