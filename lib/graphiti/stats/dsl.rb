module Graphiti
  module Stats
    # Provides an easier interface to stats scoping.
    #
    # Used within Resource DSL:
    #
    #   allow_stat total: [:count] do
    #     # ... eval'd in Stats::DSL context! ...
    #   end
    #
    # This allows us to define arbitrary stats:
    #
    #   allow_stat total: [:count] do
    #     standard_deviation { |scope, attr| ... }
    #   end
    #
    # And use convenience methods:
    #
    #   allow_stat :rating do
    #     count!
    #     average!
    #   end
    #
    # @see Resource.allow_stat
    # @attr_reader [Symbol] name the stat, e.g. :total
    # @attr_reader [Hash] calculations procs for various metrics
    class DSL
      attr_reader :name, :calculations

      # @param [Adapters::Abstract] adapter the Resource adapter
      # @param [Symbol, Hash] config example: +:total+ or +{ total: [:count] }+
      def initialize(adapter, config)
        config = {config => []} if config.is_a?(Symbol)

        @adapter = adapter
        @calculations = {}
        @name = config.keys.first
        Array(config.values.first).each { |c| send(:"#{c}!") }
      end

      # Used for defining arbitrary stats within the DSL:
      #
      #   allow_stat :total do
      #     standard_deviation { |scope, attr| ... }
      #   end
      #
      # ...will hit +method_missing+ and store the proc for future reference.
      # @api private
      def method_missing(meth, *args, &blk)
        @calculations[meth] = blk
      end
      # rubocop: enable Style/MethodMissingSuper

      def respond_to_missing?(*args)
        true
      end

      # Grab a calculation proc. Raises error if no corresponding stat
      # has been configured.
      #
      # @param [String, Symbol] name the name of the calculation, e.g. +:total+
      # @return [Proc] the proc to run the calculation
      def calculation(name)
        callable = @calculations[name] || @calculations[name.to_sym]
        callable || raise(Errors::StatNotFound.new(@name, name))
      end

      # Convenience method for default :count proc
      def count!
        @calculations[:count] = @adapter.method(:count)
      end

      # Convenience method for default :sum proc
      def sum!
        @calculations[:sum] = @adapter.method(:sum)
      end

      # Convenience method for default :average proc
      def average!
        @calculations[:average] = @adapter.method(:average)
      end

      # Convenience method for default :maximum proc
      def maximum!
        @calculations[:maximum] = @adapter.method(:maximum)
      end

      # Convenience method for default :minimum proc
      def minimum!
        @calculations[:minimum] = @adapter.method(:minimum)
      end
    end
  end
end
