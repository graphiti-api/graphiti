if ENV["APPRAISAL_INITIALIZED"]
  require "rails/generators"
  require "generators/graphiti/install_generator"
  require "fileutils"
  require "tmpdir"

  RSpec.describe Graphiti::InstallGenerator do
    let(:destination) { Dir.mktmpdir("graphiti-install") }

    def generated(path)
      File.read(File.join(destination, path))
    end

    def install!(*arguments)
      Dir.chdir(destination) do
        described_class.start(
          arguments,
          destination_root: destination, shell: Thor::Shell::Basic.new
        )
      end
    end

    before do
      allow(::Rails).to receive(:root).and_return(Pathname.new(destination))

      FileUtils.mkdir_p(File.join(destination, "app/controllers"))
      FileUtils.mkdir_p(File.join(destination, "config"))
      File.write(File.join(destination, "app/controllers/application_controller.rb"), <<~RUBY)
        class ApplicationController < ActionController::API
        end
      RUBY
      File.write(File.join(destination, "config/application.rb"), <<~RUBY)
        module Dummy
          class Application < Rails::Application
          end
        end
      RUBY
      File.write(File.join(destination, "config/routes.rb"), <<~RUBY)
        Rails.application.routes.draw do
        end
      RUBY
      # Present so the generator does not prompt for an API namespace on stdin.
      File.write(File.join(destination, ".graphiticfg.yml"), {"namespace" => "/api/v1"}.to_yaml)
    end

    after { FileUtils.remove_entry(destination) }

    it "still finishes when the app has no rails_helper to inject into" do
      install!

      expect(generated("config/routes.rb")).to include("scope path:")
    end

    it "wires the schema check into an existing rails_helper" do
      FileUtils.mkdir_p(File.join(destination, "spec"))
      File.write(File.join(destination, "spec/rails_helper.rb"), <<~RUBY)
        RSpec.configure do |config|
        end
      RUBY

      install!

      expect(generated("spec/rails_helper.rb")).to include("Graphiti::SpecHelpers::RSpec.schema!")
      expect(generated("config/routes.rb")).to include("scope path:")
    end

    it "writes the locale file too" do
      install!

      expect(File.exist?(File.join(destination, "config/locales/graphiti.en.yml"))).to eq(true)
    end

    it "leaves config/application.rb alone" do
      install!

      expect(generated("config/application.rb")).to_not include("default_url_options")
    end

    it "scopes routes under the namespace without naming ApplicationResource" do
      install!

      expect(generated("config/routes.rb"))
        .to include(%(scope path: "/api/v1", defaults: {format: :jsonapi} do))
      expect(generated("config/routes.rb")).to_not include("ApplicationResource")
    end

    it "gives ApplicationResource a base_url that stands on its own" do
      install!

      expect(generated("app/resources/application_resource.rb"))
        .to include(%(self.base_url = ENV.fetch('BASE_URL', 'http://localhost:3000')))
    end
  end
end
