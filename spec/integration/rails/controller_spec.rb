if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe Graphiti::Rails::Controller, type: :controller do
    # Graphiti applied all of this to every controller in the app until 2.0.
    # These assert the opposite: a controller that has not asked for Graphiti
    # is left alone.
    describe "a controller without it" do
      controller(ActionController::Base) do
        def index
          render json: {context: Graphiti.context}
        end
      end

      it "gets no graphiti context" do
        get :index

        expect(JSON.parse(response.body)["context"]).to eq({})
      end

      it "does not wrap actions in the debugger" do
        expect(Graphiti::Debugger).to_not receive(:debug)

        get :index
      end
    end

    describe "a controller with it" do
      controller(ActionController::Base) do
        include Graphiti::Rails::Controller

        def index
          render json: {object: Graphiti.context[:object].class.name}
        end
      end

      it "gets the graphiti context" do
        get :index

        expect(JSON.parse(response.body)["object"]).to eq(controller.class.name)
      end
    end
  end
end
