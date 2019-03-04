module Graphiti
  module Util
    class Class
      def self.infer_resource_class(parent_resource_class, sideload_name)
        namespace = namespace_for(parent_resource_class)
        inferred_name = "#{sideload_name.to_s.singularize.classify}Resource"
        klass_name = "#{namespace}::#{inferred_name}"
        tried = [klass_name, inferred_name]
        klass = klass_name.safe_constantize
        klass ||= inferred_name.safe_constantize
        unless klass
          raise Errors::ResourceNotFound.new(parent_resource_class, sideload_name, tried)
        end
        klass
      end

      def self.namespace_for(klass)
        namespace = klass.name
        return "" unless namespace
        split = namespace.split("::")
        split[0, split.length - 1].join("::")
      end
    end
  end
end
