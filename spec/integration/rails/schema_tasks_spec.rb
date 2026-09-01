if ENV["APPRAISAL_INITIALIZED"]
  require "rake"
  require "tmpdir"

  RSpec.describe "the graphiti:schema rake tasks" do
    let(:path) { File.join(@dir, "nested", "schema.json") }

    # The suite defines resources the generator cannot resolve.
    before do
      allow(Graphiti::Schema).to receive(:generate)
        .and_return({resources: [], endpoints: {}, types: {}})
    end

    around do |example|
      original = Rake.application
      Rake.application = Rake::Application.new
      Rake::Task.define_task(:environment)
      load File.expand_path("../../../lib/tasks/graphiti.rake", __dir__)

      Dir.mktmpdir do |dir|
        @dir = dir
        example.run
      end
    ensure
      Rake.application = original
    end

    def run(task)
      Rake::Task[task].invoke(path)
    end

    it "generates the file at the given path" do
      expect { run("graphiti:schema:generate") }.to output(/Schema written/).to_stdout

      expect(JSON.parse(File.read(path))).to include("resources")
    end

    it "checks a file it just generated" do
      expect { run("graphiti:schema:generate") }.to output.to_stdout
      Rake::Task["graphiti:schema:generate"].reenable

      expect { run("graphiti:schema:check") }.to output(/up to date/).to_stdout
    end

    it "fails the check when the file is missing" do
      expect { run("graphiti:schema:check") }
        .to raise_error(SystemExit)
        .and output(/Schema file not found/).to_stderr
    end
  end
end
