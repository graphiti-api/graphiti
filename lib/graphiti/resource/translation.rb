module Graphiti
  class Resource
    module Translation
      extend ActiveSupport::Concern

      class_methods do
        def i18n_scope
          [:graphiti_resource, type]
        end
      end
    end
  end
end