module Graphiti
  module Util
    class PublicIdSources
      def initialize
        @sources = {}
      end

      def register(child_resource_class, filter_name, parent_resource_class)
        key = [child_resource_class.name, filter_name.to_sym]
        registered = @sources[key]
        if registered && registered.name != parent_resource_class.name
          raise Errors::ConflictingPublicIdSource.new(child_resource_class, filter_name, registered, parent_resource_class)
        end
        @sources[key] = parent_resource_class
      end

      def [](child_resource_class, filter_name)
        klass = child_resource_class
        while klass
          source = @sources[[klass.name, filter_name.to_sym]]
          return source if source
          klass = klass.superclass
        end
      end
    end
  end
end
