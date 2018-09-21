module Graphiti
  module Util
    # @api private
    class Hash
      # Grab all keys at any level of the hash.
      #
      #   { foo: { bar: { baz: {} } } }
      #
      # Becomes
      #
      # [:foo, :bar, :bar]
      #
      # @param hash the hash we want to process
      # @param [Array<Symbol, String>] collection the memoized collection of keys
      # @return [Array<Symbol, String>] the keys
      # @api private
      def self.keys(hash, collection = [])
        hash.each_pair do |key, value|
          collection << key
          keys(value, collection)
        end

        collection
      end

      def self.include_removed?(new, old)
        new = JSONAPI::IncludeDirective.new(new).to_hash
        old = JSONAPI::IncludeDirective.new(old).to_hash

        old.each_pair do |k, v|
          if new[k]
            if include_removed?(new[k], v)
              return true
            end
          else
            return true
          end
        end
        false
      end

      # Like ActiveSupport's #deep_merge
      # @return [Hash] the merged hash
      # @api private
      def self.deep_merge!(hash, other)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
        hash.merge!(other, &merger)
      end

      # Like ActiveSupport's #deep_dup
      # @api private
      def self.deep_dup(hash)
        if hash.respond_to?(:deep_dup)
          hash.deep_dup
        else
          {}.tap do |duped|
            hash.each_pair do |key, value|
              value = deep_dup(value) if value.is_a?(Hash)
              value = value.dup if value && value.respond_to?(:dup) && ![Symbol, Integer].include?(value.class)
              duped[key] = value
            end
          end
        end
      end
    end
  end
end
