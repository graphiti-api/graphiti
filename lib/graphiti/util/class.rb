module Graphiti
  module Util
    class Class
      def self.infer_resource_class(parent_resource_class, sideload_name)
        namespace = namespace_for(parent_resource_class)
        inferred_name = "#{sideload_name.to_s.singularize.classify}Resource"
        klass = "#{namespace}::#{inferred_name}".safe_constantize
        klass ||= inferred_name.safe_constantize
        unless klass
          raise Errors::ResourceNotFound.new(parent_resource_class, sideload_name)
        end
        klass
      end

      def self.namespace_for(klass)
        namespace = klass.name
        split = namespace.split('::')
        split[0,split.length-1].join('::')
      end
    end
  end
end
