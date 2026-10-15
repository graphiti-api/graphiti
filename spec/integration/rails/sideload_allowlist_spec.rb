if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "sideload allowlist", type: :controller do
    controller(ApplicationController) do
      def index
        render jsonapi: Legacy::AuthorResource.all(params)
      end
    end

    def json
      JSON.parse(response.body)
    end

    def json_includes(type)
      json["included"].select { |i| i["type"] == type }
    end

    def queries_while
      queries = []
      subscriber = ActiveSupport::Notifications
        .subscribe("sql.active_record") do |_, _, _, _, payload|
          sql = payload[:sql]
          next if payload[:name].to_s == "SCHEMA"
          next if sql.start_with?("PRAGMA", "begin", "commit")
          queries << sql
        end
      yield
      queries
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    let!(:author) { Legacy::Author.create!(first_name: "Stephen") }
    let!(:book) { Legacy::Book.create!(title: "The Shining", author: author, genre: genre) }
    let!(:genre) { Legacy::Genre.create!(name: "Horror") }

    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with("PATH_INFO") { path }
    end

    let(:path) { "/legacy/authors" }

    context "when no sideload allowlist" do
      it "allows loading all relationships" do
        do_index({include: "books.genre"})
        expect(json_includes("books")).to_not be_blank
        expect(json_includes("genres")).to_not be_blank
      end
    end

    context "when a sideload allowlist" do
      before do
        controller.class.sideload_allowlist = {
          index: [:books],
          show: {books: :genre}
        }
      end

      it "restricts what sideloads can be loaded" do
        do_index({include: "books.genre"})
        expect(json_includes("books")).to_not be_blank
        expect(json_includes("genres")).to be_blank
      end
    end

    context "when the sideload allowlist has nested includes" do
      before do
        controller.class.sideload_allowlist = {
          index: {books: :genre}
        }
      end

      it "loads the nested sideload in one query" do
        other_genre = Legacy::Genre.create!(name: "Fantasy")
        Legacy::Book.create!(title: "The Dark Tower", author: author, genre: other_genre)

        queries = queries_while { do_index({include: "books.genre"}) }

        expect(json_includes("genres").length).to eq(2)
        expect(queries.grep(/FROM "genres"/).length).to eq(1)
      end
    end
  end
end
