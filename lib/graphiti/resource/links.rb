module Graphiti
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
      class_attribute :endpoint,
        :base_url,
        :endpoint_namespace,
        :secondary_endpoints,
        :autolink
      self.secondary_endpoints = []
      self.autolink = true

      class << self
        prepend Overrides
      end
    end

    class_methods do
      def infer_endpoint
        return unless name

        path = "/#{name.gsub('Resource', '').pluralize.underscore}".to_sym
        {
          path: path,
          full_path: full_path_for(path),
          url: url_for(path),
          actions: DEFAULT_ACTIONS.dup
        }
      end

      def primary_endpoint(path, actions = DEFAULT_ACTIONS.dup)
        path = path.to_sym
        self.endpoint = {
          path: path,
          full_path: full_path_for(path),
          url: url_for(path),
          actions: actions
        }
      end

      # NB: avoid << b/c class_attribute
      def secondary_endpoint(path, actions = DEFAULT_ACTIONS.dup)
        path = path.to_sym
        self.secondary_endpoints += [{
          path: path,
          full_path: full_path_for(path),
          url: url_for(path),
          actions: actions
        }]
      end

      def endpoints
        ([endpoint] + secondary_endpoints).compact
      end

      def allow_request?(path, action)
        endpoints.any? do |e|
          if [:update, :show, :destroy].include?(context_namespace)
            path = path.split('/')
            path.pop
            path = path.join('/')
          end

          e[:full_path].to_s == path && e[:actions].include?(context_namespace)
        end
      end

      private

      def full_path_for(path)
        [endpoint_namespace, path].join('').to_sym
      end

      def url_for(path)
        [base_url, full_path_for(path)].join('').to_sym
      end
    end
  end
end
