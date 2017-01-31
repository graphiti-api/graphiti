module JsonapiCompliable
  module Util
    class Hash
      def self.keys(hash, collection = [])
        hash.each_pair do |key, value|
          collection << key
          keys(value, collection)
        end

        collection
      end
    end
  end
end
