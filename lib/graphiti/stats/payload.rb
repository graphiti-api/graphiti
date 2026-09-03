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
      def initialize(resource, query, scope, data, group_by: nil)
        @resource = resource
        @query = query
        @scope = scope
        @data = data
        @group_by = group_by
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
        args = [@scope, @resource.model_attribute_for(name)]
        args << @resource.context if function.arity >= 3
        args << @data if function.arity == 4
        translate_group_keys(function.call(*args))
      end

      private

      def translate_group_keys(result)
        return result unless result.is_a?(Hash) && @group_by

        source = @resource.class.public_id_source_for(@group_by)
        return result unless source

        public_ids = source.public_ids_by(:_primary_key, result.keys.compact)
        result.each_with_object({}) do |(primary_key, value), translated|
          if primary_key.nil?
            translated[nil] = value
          elsif public_ids.key?(primary_key)
            translated[public_ids[primary_key]] = value
          end
        end
      end

      def each_calculation(name, calculations)
        calculations.each do |calc|
          function = @resource.stat(name, calc)
          yield calc, function
        end
      end
    end
  end
end
