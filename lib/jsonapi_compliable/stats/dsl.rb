module JsonapiCompliable
  module Stats
    class DSL
      attr_reader :name, :calculations

      def initialize(adapter, config)
        config = { config => [] } if config.is_a?(Symbol)

        @adapter = adapter
        @calculations = {}
        @name = config.keys.first
        Array(config.values.first).each { |c| send(:"#{c}!") }
      end

      def method_missing(meth, *args, &blk)
        @calculations[meth] = blk
      end

      def calculation(name)
        callable = @calculations[name] || @calculations[name.to_sym]
        callable || raise(Errors::StatNotFound.new(@name, name))
      end

      def count!
        @calculations[:count] = @adapter.method(:count)
      end

      def sum!
        @calculations[:sum] = @adapter.method(:sum)
      end

      def average!
        @calculations[:average] = @adapter.method(:average)
      end

      def maximum!
        @calculations[:maximum] = @adapter.method(:maximum)
      end

      def minimum!
        @calculations[:minimum] = @adapter.method(:minimum)
      end
    end
  end
end
