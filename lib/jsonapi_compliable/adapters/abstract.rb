module JsonapiCompliable
  module Adapters
    class Abstract
      def filter(scope, attribute, value)
        raise 'you must override #filter in an adapter subclass'
      end

      def order(scope, attribute, direction)
        raise 'you must override #order in an adapter subclass'
      end

      def paginate(scope, number, size)
        raise 'you must override #paginate in an adapter subclass'
      end

      def sideload(scope, includes)
        raise 'you must override #sideload in an adapter subclass'
      end

      def transaction
        raise 'you must override #transaction in an adapter subclass, it must yield'
      end

      def resolve(scope)
        scope
      end

      def sideloading_module
        Module.new
      end
    end
  end
end
