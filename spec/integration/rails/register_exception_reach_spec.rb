if ENV["APPRAISAL_INITIALIZED"]
  # register_exception comes from rescue_registry, which adds it to every
  # controller, and rendering happens in its middleware. Neither needs
  # Graphiti::Rails::Controller. What that adds is Graphiti's own
  # registrations and the fallback for exceptions nobody registered.
  RSpec.describe "register_exception without Graphiti::Rails::Controller", type: :request do
    include Graphiti::Rails::TestHelpers

    class BareForbidden < StandardError; end

    class BareErrorsController < ActionController::Base
      register_exception BareForbidden, status: 403

      def registered
        raise BareForbidden
      end

      def unregistered
        raise "kaboom"
      end
    end

    before do
      Rails.application.routes.draw do
        get "/bare/registered" => "bare_errors#registered"
        get "/bare/unregistered" => "bare_errors#unregistered"
      end
    end

    def get_jsonapi(path)
      handle_request_exceptions do
        get path, headers: {"HTTP_ACCEPT" => "application/vnd.api+json"}
      end
    end

    it "registers and renders an exception the controller declared" do
      get_jsonapi "/bare/registered"

      expect(response.status).to eq(403)
      expect(response.content_type).to start_with("application/vnd.api+json")
      expect(JSON.parse(response.body)["errors"][0]["code"]).to eq("forbidden")
    end

    it "leaves unregistered exceptions to Rails, having no Graphiti fallback" do
      get_jsonapi "/bare/unregistered"

      expect(response.status).to eq(500)
      expect(response.content_type).to_not include("vnd.api+json")
    end
  end
end
