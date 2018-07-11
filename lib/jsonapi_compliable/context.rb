module JsonapiCompliable
  module Context
    extend ActiveSupport::Concern

    included do
      class_attribute :_sideload_whitelist
    end

    class_methods do
      def sideload_whitelist(hash)
        self._sideload_whitelist = JSONAPI::IncludeDirective.new(hash).to_hash
      end
    end
  end
end
