module JSONAPICompliable
  module Util
    class FieldParams
      def self.parse!(params, name)
        return unless params[name]

        params[name].each_pair do |key, value|
          params[name][key] = value.split(',').map(&:to_sym)
        end
      end

      def self.fieldset(params, name)
        params[name].to_unsafe_hash.deep_symbolize_keys
      end
    end
  end
end
