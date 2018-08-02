module JsonapiCompliable
  module Links
    extend ActiveSupport::Concern

    module Overrides
      def endpoint
        if endpoint = super
          endpoint
        else
          self.endpoint = infer_endpoint
        end
      end
    end

    included do
      class_attribute :endpoint, :endpoint_namespace, :secondary_endpoints
      self.secondary_endpoints = []

      class << self
        prepend Overrides
      end
    end

    class_methods do
      def infer_endpoint
        path = "/#{name.gsub('Resource', '').pluralize.underscore}"
        actions = [:index, :show, :create, :update, :destroy]
        { path: path.to_sym, actions: actions }
      end

      # NB: avoid << b/c class_attribute
      def add_endpoint(path, actions)
        self.secondary_endpoints += [{ path: path.to_sym, actions: actions }]
      end

      def endpoints
        ([endpoint] + secondary_endpoints).compact.map do |e|
          {
            path: [endpoint_namespace, e[:path]].join('').to_sym,
            actions: e[:actions]
          }
        end
      end
    end
  end
end
