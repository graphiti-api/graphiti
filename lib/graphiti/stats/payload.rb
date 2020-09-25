module Graphiti
  module Stats
    # Generate the stats payload so we can return it in the response.
    #
    #   {
    #     data: [...],
    #     meta: { stats: the_generated_payload }
    #   }
    #
    # For example:
    #
    #   {
    #     data: [...],
    #     meta: { stats: { total: { count: 100 } } }
    #   }
    class Payload
      def initialize(resource, query, scope, data)
        @resource = resource
        @query = query
        @scope = scope
        @data = data
      end

      # Generate the payload for +{ meta: { stats: { ... } } }+
      # Loops over all calculations, computes then, and gives back
      # a hash of stats and their results.
      # @return [Hash] the generated payload
      def generate
        {}.tap do |stats|
          @query.stats.each_pair do |name, calculation|
            stats[name] = {}

            each_calculation(name, calculation) do |calc, function|
              stats[name][calc] = calculate_stat(name, function)
            end
          end
        end
      end

      def calculate_stat(name, function)
        args = [@scope, name]
        args << @resource.context if function.arity >= 3
        args << @data if function.arity == 4
        function.call(*args)
      end

      private

      def each_calculation(name, calculations)
        calculations.each do |calc|
          function = @resource.stat(name, calc)
          yield calc, function
        end
      end
    end
  end
end
