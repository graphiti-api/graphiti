module Graphiti
  module Context
    extend ActiveSupport::Concern

    module Overrides
      def sideload_allowlist=(val)
        super(JSONAPI::IncludeDirective.new(val).to_hash)
      end
    end

    included do
      class_attribute :sideload_allowlist
      self.sideload_allowlist = {}
      class << self; prepend Overrides; end
    end
  end
end
