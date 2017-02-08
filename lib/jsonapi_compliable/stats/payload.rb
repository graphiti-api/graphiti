module JsonapiCompliable
  module Stats
    class Payload
      def initialize(dsl, query_hash, scope)
        @dsl        = dsl
        @query_hash = query_hash[:stats]
        @scope      = scope
      end

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
          function = @dsl.stat(name, calc)
          yield calc, function
        end
      end
    end
  end
end
