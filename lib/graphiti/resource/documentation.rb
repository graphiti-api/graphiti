module Graphiti
  class Resource
    module Documentation
      extend ActiveSupport::Concern

      class_methods do
        def description=(val)
          @description = val
        end

        def description
          return @description if @description.present?

          if defined?(::I18n)
            desc = ::I18n.t :description,
              scope: i18n_resource_scope,
              default: nil
            desc ||= ::I18n.t :description,
              scope: i18n_type_scope,
              default: nil
          end
        end

        # @api private
        def attribute_description(attr_name)
          desc = all_attributes[attr_name][:description]
          return desc if desc.present?

          if defined?(::I18n)
            desc = ::I18n.t :description,
              scope: [*i18n_type_scope, :attributes, attr_name],
              default: nil
            desc ||= ::I18n.t :description,
              scope: [*i18n_resource_scope, :attributes, attr_name],
              default: nil
          end
        end

        private

        def underscored_resource_name
          self.name.gsub(/Resource$/, '').underscore
        end

        def i18n_resource_scope
          [:graphiti, :resources, underscored_resource_name]
        end

        def i18n_type_scope
          [:graphiti, :types, type]
        end
      end
    end
  end
end