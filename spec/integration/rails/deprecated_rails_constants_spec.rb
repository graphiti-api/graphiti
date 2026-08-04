if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "deprecated Rails constants" do
    def silenced
      Graphiti::DEPRECATOR.silence { yield }
    end

    describe "Graphiti::Responders" do
      it "resolves to Graphiti::Rails::Responders" do
        expect(silenced { Graphiti::Responders == Graphiti::Rails::Responders }).to eq(true)
      end

      it "warns when used" do
        expect(Graphiti::DEPRECATOR).to receive(:warn).at_least(:once).and_return(nil)

        Graphiti::Responders == Graphiti::Rails::Responders
      end
    end

    describe "including Graphiti::Rails" do
      it "warns" do
        expect(Graphiti::DEPRECATOR).to receive(:deprecation_warning)
          .with("Including Graphiti::Rails", a_string_including("Graphiti::Rails::Controller"))

        Class.new(ActionController::Base) { include Graphiti::Rails }
      end

      it "still sets the controller up, rather than silently doing nothing" do
        klass = silenced { Class.new(ActionController::Base) { include Graphiti::Rails } }

        expect(klass.ancestors).to include(Graphiti::Rails::Controller)
        expect(klass.ancestors).to include(Graphiti::Rails::Context)
        expect(klass.rescue_registry.handles_exception?(Graphiti::Errors::RecordNotFound.new))
          .to eq(true)
      end
    end

    describe 'require "graphiti-rails"' do
      it "still resolves" do
        expect { silenced { require "graphiti-rails" } }.to_not raise_error
      end
    end

    describe "Graphiti::Rails::DEPRECATOR" do
      it "resolves on an explicit lookup, not just lexically" do
        expect(Graphiti::Rails::DEPRECATOR).to eq(Graphiti::DEPRECATOR)
      end
    end

    describe 'require "graphiti/responders"' do
      it "still resolves" do
        expect { silenced { require "graphiti/responders" } }.to_not raise_error
      end
    end
  end
end
