if ENV["APPRAISAL_INITIALIZED"]
  require "rails/generators"
  require "generators/graphiti/resource_generator"
  require "fileutils"
  require "tmpdir"

  # graphiti-rails checked its generators' output into its own suite as
  # spec/generated/** and ran that against a dummy app. Those specs re-tested
  # behavior this suite already covers at length. What they really stood in for
  # is that the templates still produce sane code. This runs the generator
  # rather than shipping its output.
  RSpec.describe Graphiti::ResourceGenerator do
    let(:destination) { Dir.mktmpdir("graphiti-generator") }

    def generated(path)
      File.read(File.join(destination, path))
    end

    def generate!(*arguments)
      Dir.chdir(destination) do
        described_class.start(
          arguments,
          destination_root: destination, shell: Thor::Shell::Basic.new
        )
      end
    end

    before do
      stub_const("Post", Class.new)
      # The generator requires what it writes, relative to Rails.root, so each
      # run defines PostResource for real. Hidden per example so the next run
      # does not hit a superclass mismatch against the previous definition.
      allow(::Rails).to receive(:root).and_return(Pathname.new(destination))
      hide_const("PostResource")

      FileUtils.mkdir_p(File.join(destination, "config"))
      # The shape the install generator leaves behind. Resource routes are
      # injected after the scope line, which is matched on ApplicationResource.
      File.write(File.join(destination, "config/routes.rb"), <<~RUBY)
        Rails.application.routes.draw do
          scope path: ApplicationResource.endpoint_namespace, defaults: { format: :jsonapi } do
          end
        end
      RUBY
      # Present so the generator does not prompt for an API namespace on stdin.
      File.write(File.join(destination, ".graphiticfg.yml"), {"namespace" => "/api/v1"}.to_yaml)
    end

    after { FileUtils.remove_entry(destination) }

    context "when the app already has an ApplicationResource" do
      before do
        stub_const("ApplicationResource", Class.new(Graphiti::Resource) {
          self.abstract_class = true
          self.endpoint_namespace = "/api/v1"
        })

        generate!("Post", "title:string", "upvotes:integer")
      end

      it "generates a resource with the requested attributes and types" do
        resource = generated("app/resources/post_resource.rb")

        expect(resource).to include("class PostResource < ApplicationResource")
        expect(resource).to include("attribute :title, :string")
        expect(resource).to include("attribute :upvotes, :integer")
      end

      it "generates a controller wired to the resource" do
        controller = generated("app/controllers/posts_controller.rb")

        expect(controller).to include("class PostsController < ApplicationController")
        expect(controller).to include("PostResource")
      end

      it "routes the resource under the configured namespace" do
        expect(generated("config/routes.rb")).to include("resources :posts")
      end

      it "generates resource specs" do
        expect(generated("spec/resources/post/reads_spec.rb"))
          .to include("RSpec.describe PostResource, type: :resource")
        expect(File).to exist(File.join(destination, "spec/resources/post/writes_spec.rb"))
      end

      it "generates request specs under the namespace" do
        %w[index show create update destroy].each do |action|
          expect(File).to exist(File.join(destination, "spec/api/v1/posts/#{action}_spec.rb"))
        end
      end

      it "does not generate a second ApplicationResource" do
        expect(File).to_not exist(File.join(destination, "app/resources/application_resource.rb"))
      end
    end

    context "when --controller is given" do
      before do
        stub_const("ApplicationResource", Class.new(Graphiti::Resource) {
          self.abstract_class = true
          self.endpoint_namespace = "/api/v1"
        })
      end

      it "generates the controller under that name" do
        generate!("Post", "title:string", "--controller", "Api::V1::Posts")

        controller = generated("app/controllers/api/v1/posts_controller.rb")
        expect(controller).to include("class Api::V1::PostsController < ApplicationController")
        expect(controller).to include("PostResource")
      end

      it "points the route at it, since the name no longer matches the resource" do
        generate!("Post", "title:string", "--controller", "Api::V1::Posts")

        expect(generated("config/routes.rb"))
          .to include(%(resources :posts, controller: "api/v1/posts"))
      end

      it "accepts the name with or without the Controller suffix" do
        generate!("Post", "title:string", "--controller", "Api::V1::PostsController")

        expect(generated("app/controllers/api/v1/posts_controller.rb"))
          .to include("class Api::V1::PostsController")
      end

      it "singularizes to the same controller a plural name would give" do
        generate!("Post", "title:string", "--controller", "Api::V1::Post")

        expect(generated("app/controllers/api/v1/posts_controller.rb"))
          .to include("class Api::V1::PostsController")
      end

      it "leaves the resource itself unnamespaced" do
        generate!("Post", "title:string", "--controller", "Api::V1::Posts")

        expect(generated("app/resources/post_resource.rb"))
          .to include("class PostResource < ApplicationResource")
      end
    end

    context "when the app has no ApplicationResource yet" do
      before do
        hide_const("ApplicationResource")

        generate!("Post", "title:string", "--actions", "index", "show")
      end

      it "generates one to inherit from" do
        expect(generated("app/resources/application_resource.rb"))
          .to include("class ApplicationResource < Graphiti::Resource")
      end

      it "documents the inherited settings with their defaults and options" do
        contents = generated("app/resources/application_resource.rb")

        expect(contents).to include("  # Links\n")
        expect(contents).to include("# self.relationship_links                 = true          # true, false, or :on_demand")
        expect(contents).to include("# self.belongs_to_resource_ids_by_default = :foreign_key  # :foreign_key, :always, or :never")
      end

      it "only generates request specs for the requested actions" do
        expect(File).to exist(File.join(destination, "spec/api/v1/posts/index_spec.rb"))
        expect(File).to exist(File.join(destination, "spec/api/v1/posts/show_spec.rb"))
        expect(File).to_not exist(File.join(destination, "spec/api/v1/posts/destroy_spec.rb"))
      end
    end
  end
end
