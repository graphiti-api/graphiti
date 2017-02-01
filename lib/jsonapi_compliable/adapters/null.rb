module JsonapiCompliable
  module Adapters
    class Null < Abstract
      def filter(scope, attribute, value)
        scope
      end

      def order(scope, attribute, direction)
        scope
      end

      def paginate(scope, number, size)
        scope
      end

      def sideload(scope, includes)
        scope
      end
    end
  end
end
