module JsonapiCompliable
  module Links
    extend ActiveSupport::Concern

    DEFAULT_ACTIONS = [:index, :show, :create, :update, :destroy].freeze

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
        { path: path.to_sym, actions: DEFAULT_ACTIONS.dup }
      end

      def primary_endpoint(path, actions = DEFAULT_ACTIONS.dup)
        self.endpoint = { path: path.to_sym, actions: actions }
      end

      # NB: avoid << b/c class_attribute
      def secondary_endpoint(path, actions = DEFAULT_ACTIONS.dup)
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

      def allow_request?(path, action)
        endpoints.any? do |e|
          if [:update, :show, :destroy].include?(context_namespace)
            path = path.split('/')
            path.pop
            path = path.join('/')
          end

          e[:path].to_s == path && e[:actions].include?(context_namespace)
        end
      end
    end
  end
end
