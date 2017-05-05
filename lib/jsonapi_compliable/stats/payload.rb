module JsonapiCompliable
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
      # @param [Resource] resource the resource instance
      # @param [Hash] query_hash the Query#to_hash for the current resource
      # @param scope the scope we are chaining/modifying
      def initialize(resource, query_hash, scope)
        @resource   = resource
        @query_hash = query_hash[:stats]
        @scope      = scope
      end

      # Generate the payload for +{ meta: { stats: { ... } } }+
      # Loops over all calculations, computes then, and gives back
      # a hash of stats and their results.
      # @return [Hash] the generated payload
      def generate
        {}.tap do |stats|
          @query_hash.each_pair do |name, calculation|
            stats[name] = {}

            each_calculation(name, calculation) do |calc, function|
              stats[name][calc] = function.call(@scope, name)
            end
          end
        end
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
