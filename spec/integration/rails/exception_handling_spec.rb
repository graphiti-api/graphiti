if ENV["APPRAISAL_INITIALIZED"]
  # rescue_registry renders exceptions from ActionDispatch middleware, which
  # controller specs bypass entirely, so these have to be request specs.
  RSpec.describe "exception handling", type: :request do
    include Graphiti::Rails::TestHelpers

    class SpecErrorsController < ApplicationController
      def index
        raise SPEC_ERROR
      end
    end

    let(:invalid_request_errors) do
      Graphiti::Util::SimpleErrors.new(Object.new).tap do |errors|
        errors.add(:"filter.title", :unsupported, message: "is not supported")
      end
    end

    before do
      stub_const("SPEC_ERROR", error)
      Rails.application.routes.draw do
        get "/spec_errors" => "spec_errors#index"
      end
    end

    # Exceptions propagate untouched in tests unless the request is wrapped.
    def get_errors(accept: "application/vnd.api+json")
      handle_request_exceptions do
        get "/spec_errors", headers: {"HTTP_ACCEPT" => accept}
      end
    end

    let(:json) { JSON.parse(response.body) }

    context "Graphiti::Errors::InvalidRequest" do
      let(:error) { Graphiti::Errors::InvalidRequest.new(invalid_request_errors) }

      it "renders a 400 naming the rejected parameter" do
        get_errors

        expect(response.status).to eq(400)
        expect(json["errors"]).to match([a_hash_including(
          "code" => "bad_request",
          "status" => "400",
          "title" => "Request Error",
          "source" => {"pointer" => "filter/title"},
          "meta" => a_hash_including(
            "attribute" => "filter.title",
            "message" => "is not supported",
            "code" => "unsupported"
          )
        )])
      end
    end

    context "Graphiti::Errors::ConflictRequest" do
      let(:error) { Graphiti::Errors::ConflictRequest.new(invalid_request_errors) }

      it "renders a 409, not the 400 its superclass would give" do
        get_errors

        expect(response.status).to eq(409)
        expect(json["errors"][0]).to include(
          "code" => "conflict",
          "status" => "409",
          "title" => "Conflict Error"
        )
      end
    end

    context "Graphiti::Errors::RecordNotFound" do
      let(:error) { Graphiti::Errors::RecordNotFound.new("employees", 123) }

      it "renders a 404 with the exception message as detail" do
        get_errors

        expect(response.status).to eq(404)
        expect(json["errors"][0]["code"]).to eq("not_found")
        expect(json["errors"][0]["detail"])
          .to eq("The referenced resource 'employees' with id '123' could not be found.")
      end
    end

    context "a client-caused query error" do
      let(:error) do
        Graphiti::Errors::InvalidInclude.new(PORO::EmployeeResource.new, "foo")
      end

      it "renders a 400 with the exception message as detail" do
        get_errors

        expect(response.status).to eq(400)
        expect(json["errors"][0]["detail"]).to match(/"foo" is not supported/)
      end
    end

    context "paginating a sideload across multiple parents" do
      let(:error) { Graphiti::Errors::UnsupportedPagination.new }

      it "renders a 400, not the 500 an unregistered error would give" do
        get_errors

        expect(response.status).to eq(400)
        expect(json["errors"][0]["detail"]).to match(/pagination of a sideload/)
      end
    end

    context "an unregistered exception" do
      let(:error) { RuntimeError.new("boom") }

      it "is rendered as jsonapi by the fallback handler" do
        get_errors

        expect(response.status).to eq(500)
        expect(response.content_type).to start_with("application/vnd.api+json")
      end

      it "claims nothing on the application's behalf" do
        get_errors

        expect(json["errors"][0]).to eq(
          "code" => "internal_server_error",
          "status" => "500",
          "title" => "Internal Server Error"
        )
      end

      context "when a locale names the error" do
        around do |example|
          original = ::I18n.backend
          ::I18n.backend = ::I18n::Backend::Simple.new
          ::I18n.backend.store_translations(:en, graphiti: {
            errors: {internal_server_error: {title: "Omethingsay entway ongwray", detail: "Ytray againway ortlyshay."}}
          })
          example.run
        ensure
          ::I18n.backend = original
        end

        it "renders the title and detail from it" do
          get_errors

          expect(json["errors"][0]).to include(
            "title" => "Omethingsay entway ongwray",
            "detail" => "Ytray againway ortlyshay."
          )
        end
      end

      # The override dropped rescue_registry's status_code >= 500 guard, so the
      # lookup runs at every status the fallback passes through to.
      context "when the exception passes through to a status of its own" do
        let(:error) { ActionController::RoutingError.new("nope") }

        around do |example|
          original = ::I18n.backend
          ::I18n.backend = ::I18n::Backend::Simple.new
          ::I18n.backend.store_translations(:en, graphiti: {
            errors: {not_found: {detail: "Onegay orevermoreflay."}}
          })
          example.run
        ensure
          ::I18n.backend = original
        end

        it "reads the detail keyed by that status, not the fallback's" do
          get_errors

          expect(response.status).to eq(404)
          expect(json["errors"][0]).to include(
            "code" => "not_found",
            "detail" => "Onegay orevermoreflay."
          )
        end
      end

      # FallbackHandler returns nil for anything outside
      # handled_exception_formats, handing the request back to Rails.
      it "is left to Rails for formats Graphiti does not handle" do
        get_errors(accept: "text/html")

        expect(response.status).to eq(500)
        expect(response.content_type).to_not include("vnd.api+json")
      end
    end

    context "when request exception handling is turned off" do
      let(:error) { Graphiti::Errors::RecordNotFound.new }

      it "lets the exception through so specs can assert on it directly" do
        handle_request_exceptions(false) do
          expect {
            get "/spec_errors", headers: {"HTTP_ACCEPT" => "application/vnd.api+json"}
          }.to raise_error(Graphiti::Errors::RecordNotFound)
        end
      end

      it "restores the previous setting afterwards" do
        handle_request_exceptions(false) {}

        get_errors

        expect(response.status).to eq(404)
      end
    end
  end
end
