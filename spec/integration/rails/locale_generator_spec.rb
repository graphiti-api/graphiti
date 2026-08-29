if ENV["APPRAISAL_INITIALIZED"]
  require "rails/generators"
  require "generators/graphiti/locale_generator"
  require "fileutils"
  require "tmpdir"
  require "yaml"

  RSpec.describe Graphiti::LocaleGenerator do
    let(:destination) { Dir.mktmpdir("graphiti-locale") }

    def generated
      File.read(File.join(destination, "config/locales/graphiti.en.yml"))
    end

    def generate!(*arguments)
      described_class.start(
        arguments,
        destination_root: destination, shell: Thor::Shell::Basic.new
      )
    end

    after { FileUtils.remove_entry(destination) }

    it "writes every message Graphiti renders" do
      generate!

      locale = YAML.safe_load(generated)

      expect(locale.dig("en", "graphiti", "errors", "messages"))
        .to eq(Graphiti::Util::SimpleErrors::DEFAULT_MESSAGES.transform_keys(&:to_s))
      expect(locale.dig("en", "graphiti", "errors", "format"))
        .to eq(Graphiti::Util::SimpleErrors::DEFAULT_FORMAT)
    end

    it "documents the title and detail keys, which have no defaults to write" do
      generate!

      expect(generated).to include("internal_server_error")
    end

    it "omits the comments when asked" do
      generate!("--omit-comments")

      expect(generated).to_not include("#")
    end
  end
end
