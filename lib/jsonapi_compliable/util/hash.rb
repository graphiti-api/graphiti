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

      def self.deep_merge!(hash, other)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
        hash.merge!(other, &merger)
      end

      def self.deep_dup(hash)
        if hash.respond_to?(:deep_dup)
          hash.deep_dup
        else
          {}.tap do |duped|
            hash.each_pair do |key, value|
              value = deep_dup(value) if value.is_a?(Hash)
              value = value.dup if value && value.respond_to?(:dup) && ![Symbol, Fixnum].include?(value.class)
              duped[key] = value
            end
          end
        end
      end
    end
  end
end
