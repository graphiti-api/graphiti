module JsonapiCompliable
  module Stats
    class DSL
      attr_reader :name, :calculations

      def self.defaults
        {
          count: ->(scope, attr) { scope.count },
          average: ->(scope, attr) { scope.average(attr).to_f },
          sum: ->(scope, attr) { scope.sum(attr) },
          maximum: ->(scope, attr) { scope.maximum(attr) },
          minimum: ->(scope, attr) { scope.minimum(attr) }
        }
      end

      def initialize(config)
        config = { config => [] } if config.is_a?(Symbol)

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
        @calculations[:count] = self.class.defaults[:count]
      end

      def sum!
        @calculations[:sum] = self.class.defaults[:sum]
      end

      def average!
        @calculations[:average] = self.class.defaults[:average]
      end

      def maximum!
        @calculations[:maximum] = self.class.defaults[:maximum]
      end

      def minimum!
        @calculations[:minimum] = self.class.defaults[:minimum]
      end
    end
  end
end
