module Graphiti
  module Links
    extend ActiveSupport::Concern

    DEFAULT_ACTIONS = [:index, :show, :create, :update, :destroy].freeze

    module Overrides
      def endpoint
        if (endpoint = super)
          endpoint
        elsif !@__skip_inference
          self.endpoint = infer_endpoint
        end
      end

      def endpoint=(value)
        # changes introduced in Ruby 3.2 and above require some extra hoops
        # to allow .endpoint = nil to work properly
        @__skip_inference = value.blank?
        super
      end
    end

    included do
      class_attribute :endpoint,
        :base_url,
        :endpoint_namespace,
        :secondary_endpoints,
        :autolink,
        :validate_endpoints
      self.secondary_endpoints = []
      self.autolink = true
      self.validate_endpoints = true

      class << self
        prepend Overrides
      end
    end

    class_methods do
      def infer_endpoint
        return unless name

        path = "/#{name.gsub("Resource", "").pluralize.underscore}".to_sym
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

      def allow_request?(request_path, params, action)
        request_path = request_path.split(".")[0]

        endpoints.any? do |e|
          has_id = params[:id] || params[:data].try(:[], :id)
          path = request_path
          if [:update, :show, :destroy].include?(action) && has_id
            path = request_path.split("/")
            path.pop if Graphiti::Util::UriDecoder.decode_uri(path.last) == has_id.to_s
            path = path.join("/")
          end
          e[:full_path].to_s == path && e[:actions].include?(action)
        end
      end

      private

      def full_path_for(path)
        [endpoint_namespace, path].join("").to_sym
      end

      def url_for(path)
        [base_url, full_path_for(path)].join("").to_sym
      end
    end
  end
end
