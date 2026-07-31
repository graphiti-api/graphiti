if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe Graphiti::Rails::Debugging, type: :controller do
    controller(ApplicationController) do
      def index
        render json: {}
      end
    end

    it "comes along with Graphiti::Rails::Controller" do
      expect(controller).to be_a(described_class)
    end

    it "wraps the action in a debugger" do
      ran_inside_debugger = false
      allow(Graphiti::Debugger).to receive(:debug).and_wrap_original do |original, &block|
        original.call do
          ran_inside_debugger = true
          block.call
        end
      end

      get :index

      expect(ran_inside_debugger).to eq(true)
    end
  end
end
