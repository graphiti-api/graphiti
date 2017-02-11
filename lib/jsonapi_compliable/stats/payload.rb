module JsonapiCompliable
  module Stats
    class Payload
      def initialize(resource, query_hash, scope)
        @resource   = resource
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
          function = @resource.stat(name, calc)
          yield calc, function
        end
      end
    end
  end
end
