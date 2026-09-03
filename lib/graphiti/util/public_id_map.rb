module Graphiti
  module Util
    class PublicIdMap
      def initialize(resource_class, filter_name)
        @resource_class = resource_class
        @filter_name = filter_name
        @pending = Concurrent::Map.new
        @resolved = {}
      end

      def add(primary_keys)
        primary_keys.each { |key| @pending[key] = true unless @resolved.key?(key) }
      end

      def [](primary_key)
        return if primary_key.nil?

        resolve(@pending.keys) unless @pending.empty?
        resolve([primary_key]) unless @resolved.key?(primary_key)
        @resolved[primary_key]
      end

      private

      def resolve(primary_keys)
        found = @resource_class.public_ids_by(@filter_name, primary_keys)
        primary_keys.each do |key|
          @pending.delete(key)
          @resolved[key] = found[key]
        end
      end
    end
  end
end
