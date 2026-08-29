if ENV["APPRAISAL_INITIALIZED"]
  # Graphiti.config's own Rails defaults (schema_path, logger, debug) are covered
  # in spec/configuration_spec.rb. This covers what the Railtie registers with
  # Rails on boot.
  RSpec.describe Graphiti::Rails::Railtie do
    describe "the jsonapi mime type" do
      it "is registered" do
        expect(Mime[:jsonapi].to_s).to eq("application/vnd.api+json")
      end
    end

    describe "the jsonapi parameter parser" do
      subject(:parser) { ActionDispatch::Request.parameter_parsers[:jsonapi] }

      it "is registered" do
        expect(parser).to be_a(Proc)
      end

      it "parses a jsonapi body into params readable by string or symbol" do
        parsed = parser.call({data: {type: "authors"}}.to_json)

        expect(parsed[:data][:type]).to eq("authors")
        expect(parsed["data"]["type"]).to eq("authors")
      end
    end

    describe "renderers" do
      it "registers jsonapi and jsonapi_errors" do
        expect(ActionController::Renderers::RENDERERS)
          .to include(:jsonapi, :jsonapi_errors)
      end
    end

    describe "config.graphiti options" do
      it "defaults handled_exception_formats to jsonapi" do
        expect(Graphiti::Rails.handled_exception_formats).to eq([:jsonapi])
      end

      it "defaults respond_to_formats to json, jsonapi and xml" do
        expect(Graphiti::Rails.respond_to_formats)
          .to eq([:json, :jsonapi, :xml])
      end
    end

    describe "endpoint lookup" do
      it "is configured" do
        expect(Graphiti.config.context_for_endpoint).to be_a(Proc)
      end
    end

    describe "rescue_responses" do
      let(:controller) do
        Class.new(ActionController::Base) { include Graphiti::Rails::Controller }
      end

      it "tells Rails which Graphiti errors are client errors" do
        expect(ActionDispatch::ExceptionWrapper.rescue_responses)
          .to include(Graphiti::Rails::CLIENT_ERROR_STATUSES)
      end

      it "keeps them out of the error reporter" do
        wrapper = ActionDispatch::ExceptionWrapper
          .new(nil, Graphiti::Errors::RecordNotFound.new)

        expect(wrapper.rescue_response?).to eq(true)
      end

      it "gives each the status the controller renders" do
        Graphiti::Rails::CLIENT_ERROR_STATUSES.each do |name, status|
          registered = controller.rescue_registry
            .status_code_for_exception(name.constantize, passthrough: false)

          expect(registered).to eq(Rack::Utils.status_code(status)), name
        end
      end

      it "covers every client error the controller registers" do
        handlers = controller.rescue_registry.instance_variable_get(:@handlers)
        client_errors = handlers.select { |_, (_, options)|
          (400..499).cover?(options[:status])
        }

        expect(client_errors.keys.map(&:name))
          .to match_array(Graphiti::Rails::CLIENT_ERROR_STATUSES.keys)
      end
    end

    describe "rake tasks" do
      it "ships the graphiti tasks the Railtie loads" do
        task_path = File.expand_path("../../../lib/tasks/graphiti.rake", __dir__)

        expect(File.exist?(task_path)).to eq(true)
      end
    end
  end
end
