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

    describe "Graphiti::Railtie" do
      it "resolves to Graphiti::Rails::Railtie" do
        expect(silenced { Graphiti::Railtie == Graphiti::Rails::Railtie }).to eq(true)
      end
    end

    describe 'require "graphiti/railtie"' do
      it "still resolves" do
        expect { silenced { require "graphiti/railtie" } }.to_not raise_error
      end
    end

    describe "Graphiti::Rails::GraphitiErrorsTesting" do
      it "resolves to Graphiti::Rails::TestHelpers" do
        expect(silenced { Graphiti::Rails::GraphitiErrorsTesting == Graphiti::Rails::TestHelpers })
          .to eq(true)
      end
    end

    describe "GraphitiErrors.disable!/enable!" do
      around do |example|
        original = ::Rails.application.config.action_dispatch.show_exceptions
        example.run
      ensure
        ::Rails.application.config.action_dispatch.show_exceptions = original
        ::Rails.application.env_config["action_dispatch.show_exceptions"] = original
      end

      it "warns" do
        expect(Graphiti::DEPRECATOR).to receive(:deprecation_warning)
          .with("GraphitiErrors.disable!", a_string_including("handle_request_exceptions"))

        GraphitiErrors.disable!
      end

      it "still toggles exception rendering" do
        silenced do
          GraphitiErrors.enable!
          expect(GraphitiErrors.disabled?).to eq(false)

          GraphitiErrors.disable!
          expect(GraphitiErrors.disabled?).to eq(true)
        end
      end
    end
  end
end
