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
            desc
          end
        end

        # @api private
        def attribute_description(attr_name)
          desc = all_attributes[attr_name][:description]
          return desc if desc.present?

          resolve_i18n_field_description(attr_name, field_type: :attributes)
        end

        # @api private
        def sideload_description(sideload_name)
          sideloads[sideload_name].description
        end

        # @api private
        def resolve_i18n_field_description(name, field_type:)
          if defined?(::I18n)
            desc = ::I18n.t :description,
              scope: [*i18n_type_scope, field_type, name],
              default: nil
            desc ||= ::I18n.t :description,
              scope: [*i18n_resource_scope, field_type, name],
              default: nil
            desc
          end
        end

        private

        def underscored_resource_name
          name.gsub(/Resource$/, "").underscore
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
