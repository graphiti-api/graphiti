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

    it "writes the title Graphiti renders for every code" do
      generate!

      titles = YAML.safe_load(generated)
        .dig("en", "graphiti", "errors")
        .slice(*Graphiti::LocaleGenerator::ERROR_TITLES.keys.map(&:to_s))
        .transform_values { |entry| entry["title"] }

      expect(titles).to eq(Graphiti::LocaleGenerator::ERROR_TITLES.transform_keys(&:to_s))
    end

    it "names the exceptions behind each registered code" do
      generate!

      expect(generated).to include("# RecordNotFound")
      expect(generated).to include("# ConflictRequest")
      expect(generated).to include("# InvalidRequest, RemoteWrite,")
    end

    it "names every registered exception, so a new one cannot go undocumented" do
      generate!

      Graphiti::Rails::CLIENT_ERROR_STATUSES.each_key do |exception|
        expect(generated).to include(exception.delete_prefix("Graphiti::Errors::"))
      end
    end

    it "gives the fallback a detail, since nothing else reports one for it" do
      generate!

      expect(YAML.safe_load(generated).dig("en", "graphiti", "errors", "internal_server_error"))
        .to eq(
          "title" => "Internal Server Error",
          "detail" => "We've probably received an error report already, but please contact us if the issue persists."
        )
    end

    it "writes a detail for no other code" do
      generate!

      codes = YAML.safe_load(generated).dig("en", "graphiti", "errors")

      expect(codes.select { |_code, entry| entry.is_a?(Hash) && entry.key?("detail") }.keys)
        .to eq(["internal_server_error"])
    end

    it "still writes the detail with comments omitted" do
      generate!("--omit-comments")

      expect(YAML.safe_load(generated).dig("en", "graphiti", "errors", "internal_server_error", "detail"))
        .to eq("We've probably received an error report already, but please contact us if the issue persists.")
    end

    it "omits the comments when asked" do
      generate!("--omit-comments")

      expect(generated).to_not include("#")
    end
  end
end
