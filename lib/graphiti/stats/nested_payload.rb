module Graphiti
  module Stats
    # Generate the nested stats payload so we can return it in the response for each record i.e.
    #
    #   {
    #     data: [
    #       {
    #         id: "1",
    #         type: "employee",
    #         attributes: {},
    #         relationships: {},
    #         meta: { stats: { total: { count: 100 } } }
    #       }
    #     ],
    #     meta: {}
    #   }

    class NestedPayload
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
            nested_on = @resource.stats[name].nested_on
            next if nested_on.blank?

            stats[nested_on] ||= {}

            each_calculation(name, calculation) do |calc, function|
              data_arr = @data.is_a?(Enumerable) ? @data : [@data]

              data_arr.each do |object|
                args = [@scope, name]
                args << @resource.context if function.arity >= 3
                args << object if function.arity == 4
                result = function.call(*args)

                stats[nested_on][object.id] ||= {}
                stats[nested_on][object.id][name] ||= {}
                stats[nested_on][object.id][name][calc] = result
              end
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
