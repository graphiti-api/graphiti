if ENV["APPRAISAL_INITIALIZED"]
  require "rake"
  require "graphiti/rails/rake_helpers"

  RSpec.describe "graphiti rake task arguments" do
    around do |example|
      original = Rake.application
      Rake.application = Rake::Application.new
      Rake::Task.define_task(:environment)
      load File.expand_path("../../../lib/tasks/graphiti.rake", __dir__)
      example.run
    ensure
      Rake.application = original
    end

    describe "graphiti:request" do
      before do
        allow(Graphiti::Rails::RakeHelpers).to receive(:setup_rails!)
        allow(Graphiti::Rails::RakeHelpers).to receive(:make_request).and_return({})
      end

      def invoke(*arguments)
        Rake::Task["graphiti:request"].invoke(*arguments)
      end

      it "leaves debug off when it is not asked for" do
        expect(Graphiti::Rails::RakeHelpers)
          .to receive(:make_request).with("/employees", false)

        invoke("/employees")
      end

      it "turns debug on for true" do
        expect(Graphiti::Rails::RakeHelpers)
          .to receive(:make_request).with("/employees", true)

        invoke("/employees", "true")
      end

      # Rake arguments arrive as Strings, and "false" is truthy in Ruby.
      it "leaves debug off for false" do
        expect(Graphiti::Rails::RakeHelpers)
          .to receive(:make_request).with("/employees", false)

        invoke("/employees", "false")
      end
    end

    describe "graphiti:benchmark" do
      it "says how to pass a request count rather than dividing by zero" do
        expect(Graphiti::Rails::RakeHelpers).to_not receive(:make_request)

        expect {
          Rake::Task["graphiti:benchmark"].invoke("/employees")
        }.to raise_error(SystemExit)
          .and output(/Needs a request count/).to_stderr
      end
    end
  end
end
