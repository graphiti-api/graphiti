module JsonapiCompliable
  module Stats
    class Payload
      def initialize(controller, scope)
        @dsl       = controller._jsonapi_compliable
        @directive = controller.params[:stats]
        @scope     = controller._jsonapi_scope || scope
      end

      def generate
        {}.tap do |stats|
          @directive.each_pair do |name, calculation|
            stats[name] = {}

            each_calculation(name, parse_calculation(calculation)) do |calc, function|
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

      def parse_calculation(calculation)
        if calculation.is_a?(String)
          calculation.split(',').map(&:to_sym)
        else
          calculation.map(&:to_sym)
        end
      end
    end
  end
end
