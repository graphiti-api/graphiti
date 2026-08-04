RSpec.describe "graphiti without Rails" do
  describe "the gemspec" do
    let(:gemspec) do
      Gem::Specification.load(File.expand_path("../graphiti.gemspec", __dir__))
    end

    # The Rails integration ships inside this gem as of 2.0. It has to stay
    # opt-in at load time rather than becoming a dependency, or every non-Rails
    # user installs Rails to use Graphiti.
    it "does not depend on Rails" do
      runtime = gemspec.dependencies
        .select { |dependency| dependency.type == :runtime }
        .map(&:name)

      expect(runtime).to_not include("rails", "railties", "actionpack", "activerecord")
    end
  end

  # Only meaningful in the run that has no Rails in the bundle at all: the
  # plain Gemfile rows of the CI matrix.
  if !defined?(::Rails)
    describe "loading" do
      it "does not define the Rails integration" do
        expect(defined?(Graphiti::Rails)).to be_nil
      end

      it "ships the Rails integration without loading it" do
        expect(File).to exist(File.expand_path("../lib/graphiti/rails.rb", __dir__))
      end

      it "does not pull ActionController in" do
        expect(defined?(::ActionController::Base)).to be_nil
      end
    end

    describe "a process that requires nothing but graphiti" do
      # This suite loads active_model, active_record and more, any of which
      # pulls in enough of ActiveSupport to hide a missing require in
      # lib/graphiti.rb. A bare subprocess is the only way to see what an app
      # that requires graphiti and nothing else actually gets.
      it "renders" do
        script = <<~RUBY
          require "graphiti"

          class Post < Graphiti::Resource
            self.adapter = Graphiti::Adapters::Null
            self.model = Struct.new(:id, :title, keyword_init: true)
            self.validate_endpoints = false
            attribute :title, :string
            def base_scope = {}
            def resolve(_scope) = [model.new(id: 1, title: "Bare")]
          end

          print Graphiti.with_context(Object.new, :index) { Post.all({}).to_jsonapi }
        RUBY

        output = nil
        Bundler.with_unbundled_env do
          IO.popen(["ruby", "-I", File.expand_path("../lib", __dir__), "-e", script], err: [:child, :out]) do |io|
            output = io.read
          end
        end

        expect($?).to be_success, "subprocess failed:\n#{output}"
        expect(JSON.parse(output)["data"][0]["attributes"]["title"]).to eq("Bare")
      end
    end

    describe "the library itself" do
      it "resolves resources and renders without Rails" do
        resource = Class.new(PORO::EmployeeResource) do
          def self.name
            "PORO::EmployeeResource"
          end
        end
        PORO::Employee.create(first_name: "Jane")

        rendered = JSON.parse(resource.all({}).to_jsonapi)

        expect(rendered["data"].map { |d| d["attributes"]["first_name"] })
          .to eq(["Jane"])
      end
    end
  end
end
