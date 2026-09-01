if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe Graphiti::Rails::Context, type: :controller do
    controller(ApplicationController) do
      def index
        render json: {
          object: Graphiti.context[:object].class.name,
          action: Graphiti.context[:action]
        }
      end
    end

    it "comes along with Graphiti::Rails::Controller" do
      expect(controller).to be_a(described_class)
    end

    it "defaults the context to the controller instance" do
      expect(controller.graphiti_context).to eq(controller)
    end

    it "wraps the action in a context of the controller and the action name" do
      wrapped = nil
      allow(Graphiti).to receive(:with_context).and_wrap_original do |original, object, action, &block|
        wrapped = [object, action]
        original.call(object, action, &block)
      end

      get :index

      expect(wrapped).to eq([controller, :index])
    end

    it "exposes the context to resources for the duration of the action" do
      get :index

      body = JSON.parse(response.body)
      expect(body["object"]).to eq(controller.class.name)
      expect(body["action"]).to eq("index")
    end

    it "unsets the context once the action returns" do
      get :index

      expect(Graphiti.context).to eq({})
    end

    context "when the controller overrides graphiti_context" do
      controller(ApplicationController) do
        def index
          render json: {object: Graphiti.context[:object]}
        end

        def graphiti_context
          "custom"
        end
      end

      it "wraps the action in that context instead" do
        get :index

        expect(JSON.parse(response.body)["object"]).to eq("custom")
      end
    end

    context "when the controller overrides the deprecated jsonapi_context" do
      controller(ApplicationController) do
        def index
          render json: {object: Graphiti.context[:object]}
        end

        def jsonapi_context
          "legacy"
        end
      end

      it "still uses it, and deprecates the override" do
        expect(Graphiti::DEPRECATOR).to receive(:deprecation_warning)
          .with("Overriding jsonapi_context", "Override #graphiti_context instead")

        get :index

        expect(JSON.parse(response.body)["object"]).to eq("legacy")
      end
    end
  end
end
