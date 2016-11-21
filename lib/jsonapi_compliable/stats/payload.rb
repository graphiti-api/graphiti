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

            each_calculation(name, calculation) do |calc, function|
              stats[name][calc] = function.call(@scope, name)
            end
          end
        end
      end

      private

      def each_calculation(name, calculation_string)
        calculations = calculation_string.split(',').map(&:to_sym)

        calculations.each do |calc|
          function = @dsl.stat(name, calc)
          yield calc, function
        end
      end
    end
  end
end
