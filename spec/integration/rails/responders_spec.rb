if ENV["APPRAISAL_INITIALIZED"]
  # Rails extracted respond_with into the responders gem. An app gets it from
  # Bundler.require. The bare app this suite boots has to ask for it.
  require "responders"

  RSpec.describe Graphiti::Rails::Responders, type: :controller do
    controller(ApplicationController) do
      include Graphiti::Rails::Responders

      def index
        respond_with(Legacy::AuthorResource.all(params))
      end
    end

    let!(:author) { Legacy::Author.create!(first_name: "Stephen") }

    # The resource validates that the request path is one of its endpoints, and
    # an anonymous controller has no route matching it.
    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with("PATH_INFO") { "/legacy/authors" }
    end

    it "responds to the configured formats" do
      expect(controller.class.mimes_for_respond_to.keys)
        .to match_array(Graphiti::Rails.respond_to_formats)
    end

    it "renders jsonapi through respond_with" do
      request.accept = "application/vnd.api+json"

      get :index

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)["data"].map { |d| d["id"] })
        .to eq([author.id.to_s])
    end

    describe "the respond_with location override" do
      # This is the only behaviour the module adds beyond declaring formats.
      # Rails' responder builds a Location header for a created resource by
      # calling polymorphic_url on it, which expects an ActiveModel. A
      # Graphiti::ResourceProxy is not one.
      controller(ApplicationController) do
        include Graphiti::Rails::Responders

        def create
          respond_with(Legacy::AuthorResource.build(params).tap(&:save))
        end
      end

      let(:payload) do
        {data: {type: "authors", attributes: {first_name: "Stephen"}}}
      end

      it "creates without trying to generate a url for the proxy" do
        request.accept = "application/vnd.api+json"

        post :create, params: payload

        expect(response.status).to eq(201)
        expect(response.headers["Location"]).to be_nil
      end

      it "is what stops respond_with raising on the proxy" do
        plain = Class.new(ApplicationController) do
          include ActionController::MimeResponds
          respond_to :jsonapi
        end

        expect(plain.instance_method(:respond_with).owner)
          .to_not eq(Graphiti::Rails::Responders)
        expect(described_class.instance_method(:respond_with).owner)
          .to eq(described_class)
      end
    end
  end
end
