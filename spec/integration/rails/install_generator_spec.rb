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

    it "writes the locale file too" do
      install!

      expect(File.exist?(File.join(destination, "config/locales/graphiti.en.yml"))).to eq(true)
    end
  end
end
