module Graphiti
  module Util
    # @api private
    class FieldParams
      def self.parse(params)
        return {} if params.nil?

        {}.tap do |parsed|
          params.each_pair do |key, value|
            parsed[key.to_sym] = value.split(",").map(&:to_sym)
          end
        end
      end
    end
  end
end
