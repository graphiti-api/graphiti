module JsonapiCompliable
  module Errors
    class BadFilter < StandardError; end

    class UnsupportedPageSize < StandardError
      def initialize(size, max)
        @size, @max = size, max
      end

      def message
        "Requested page size #{@size} is greater than max supported size #{@max}"
      end
    end
  end
end
