module Graphiti
  module Util
    class PublicIdSources
      def initialize
        @sources = {}
        @type_filters = {}
      end

      # Every parent of a polymorphic has_many shares one inverse filter, so each registers under the type its type filter names.
      def register(child_resource_class, filter_name, parent_resource_class, polymorphic_type: nil, type_filter: nil)
        key = [child_resource_class.name, filter_name.to_sym, polymorphic_type]
        registered = @sources[key]
        if registered && registered.name != parent_resource_class.name
          raise Errors::ConflictingPublicIdSource.new(child_resource_class, filter_name, registered, parent_resource_class)
        end
        @sources[key] = parent_resource_class
        @type_filters[[child_resource_class.name, filter_name.to_sym]] = type_filter.to_sym if type_filter
      end

      def [](child_resource_class, filter_name, polymorphic_type = nil)
        each_ancestor_name(child_resource_class) do |name|
          source = @sources[[name, filter_name.to_sym, polymorphic_type]]
          return source if source
        end
      end

      def type_filter(child_resource_class, filter_name)
        each_ancestor_name(child_resource_class) do |name|
          type_filter = @type_filters[[name, filter_name.to_sym]]
          return type_filter if type_filter
        end
      end

      def any(child_resource_class, filter_name)
        each_ancestor_name(child_resource_class) do |name|
          entry = @sources.find { |(child, filter, _type), _source| child == name && filter == filter_name.to_sym }
          return entry.last if entry
        end
      end

      private

      def each_ancestor_name(klass)
        while klass
          yield klass.name
          klass = klass.superclass
        end
        nil
      end
    end
  end
end
