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

    describe "rake tasks" do
      it "ships the graphiti tasks the Railtie loads" do
        task_path = File.expand_path("../../../lib/tasks/graphiti.rake", __dir__)

        expect(File.exist?(task_path)).to eq(true)
      end
    end
  end
end
