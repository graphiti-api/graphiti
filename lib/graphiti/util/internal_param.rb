module Graphiti
  module Util
    # Request params can only ever be strings, arrays and hashes, so a value wrapped in this class must have come from Graphiti itself.
    class InternalParam
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def blank?
        value.blank?
      end
    end
  end
end
