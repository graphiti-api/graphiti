module Graphiti
  class Resource
    module Remote
      extend ActiveSupport::Concern

      included do
        self.adapter = Graphiti::Adapters::GraphitiAPI
        self.model = OpenStruct
        self.validate_endpoints = false

        class_attribute :timeout,
          :open_timeout
      end

      class_methods do
        def remote_url
          [remote_base_url, remote].join
        end
      end

      def save(model, meta)
        if meta[:attributes] == {} && meta[:method] == :update
          model
        else
          raise Errors::RemoteWrite.new(self.class)
        end
      end

      def destroy(*args)
        raise Errors::RemoteWrite.new(self.class)
      end

      def before_resolve(scope, query)
        scope[:params] = Util::RemoteParams.generate(self, query)
        scope
      end

      # Forward all headers
      def request_headers
        {}.tap do |headers|
          # TODO: Maybe handle this in graphiti-rails
          if defined?(Rails) && context
            raw = context.request.headers.to_h
            if (auth = raw["HTTP_AUTHORIZATION"])
              headers["Authorization"] = auth
            end
          end
        end
      end

      def remote_url
        self.class.remote_url
      end

      def make_request(url)
        headers = request_headers.dup
        headers["Content-Type"] = "application/vnd.api+json"
        faraday.get(url, nil, headers) do |req|
          yield req if block_given? # for super do ... end
          req.options.timeout = timeout if timeout
          req.options.open_timeout = open_timeout if open_timeout
        end
      end

      private

      def faraday
        if defined?(Faraday)
          Faraday
        else
          raise "Faraday not defined. Please require the 'faraday' gem to use remote resources"
        end
      end
    end
  end
end
