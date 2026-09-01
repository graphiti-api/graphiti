module Graphiti
  module ErrorSerializers
    module TranslatedTitle
      private

      def title
        return default_title unless defined?(::I18n)

        ::I18n.t :title, scope: [:graphiti, :errors, code], default: default_title
      end
    end
  end
end
