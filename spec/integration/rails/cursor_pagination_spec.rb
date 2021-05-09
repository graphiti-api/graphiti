if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "cursor pagination", type: :controller do
    include GraphitiSpecHelpers

    controller(ApplicationController) do
      def index
        records = resource.all(params)
        render jsonapi: records
      end

      def resource
        Legacy::AuthorResource
      end
    end

    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with("PATH_INFO") { path }
    end

    let(:path) { "/legacy/authors" }

    let!(:author1) { Legacy::Author.create!(age: 10, last_login: 4.day.ago) }
    let!(:author2) { Legacy::Author.create!(age: 20, last_login: 2.days.ago) }
    let!(:author3) { Legacy::Author.create!(age: 20, last_login: 3.days.ago) }
    let!(:author4) { Legacy::Author.create!(age: 30, last_login: 1.days.ago) }

    around do |e|
      original = Legacy::AuthorResource.cursor_paginatable
      Legacy::AuthorResource.cursor_paginatable = true
      begin
        e.run
      ensure
        Legacy::AuthorResource.cursor_paginatable = original
      end
    end

    def decode(cursor)
      Graphiti::Util::Cursor.decode(Legacy::AuthorResource.new, cursor)
    end

    # don't go through 'd' helper b/c it is memoized
    def ids
      json["data"].map { |d| d["id"].to_i }
    end

    it "renders a cursor in meta" do
      do_index({})
      decoded = decode(json["data"][0]["meta"]["cursor"])
      expect(decoded).to eq([{attribute: :id, direction: "asc", value: 1}])
      decoded = decode(json["data"][1]["meta"]["cursor"])
      expect(decoded).to eq([{attribute: :id, direction: "asc", value: 2}])
    end

    describe "using a rendered cursor" do
      context "when paginating after" do
        context "basic" do
          it "works" do
            do_index({})
            cursor = json["data"][1]["meta"]["cursor"]
            do_index(page: {after: cursor})
            expect(ids).to eq([author3.id, author4.id])
          end

          it "respects page size" do
            do_index({})
            cursor = json["data"][1]["meta"]["cursor"]
            do_index(page: {after: cursor, size: 1})
            expect(ids).to eq([author3.id])
          end
        end

        context "when given sort param" do
          context "that is cursorable" do
            it "works asc" do
              do_index(sort: "last_login")
              expect(ids).to eq([author1.id, author3.id, author2.id, author4.id])
              cursor = json["data"][0]["meta"]["cursor"]
              do_index(sort: "last_login", page: {after: cursor})
              expect(ids).to eq([author3.id, author2.id, author4.id])
            end

            it "works desc" do
              do_index(sort: "-last_login")
              expect(ids).to eq([4, 2, 3, 1])
              cursor = json["data"][0]["meta"]["cursor"]
              do_index(sort: "-last_login", page: {after: cursor})
              expect(ids).to eq([author2.id, author3.id, author1.id])
            end
          end

          context "that is not cursorable" do
            it "works asc" do
              do_index(sort: "age")
              expect(ids).to eq([1, 2, 3, 4])
              cursor = json["data"][1]["meta"]["cursor"] # author2, age 20
              do_index(sort: "age", page: {after: cursor})
              expect(ids).to eq([author3.id, author4.id])
            end

            it "works desc" do
              do_index(sort: "-age")
              # this order because id is secondary sort
              expect(ids).to eq([4, 2, 3, 1])
              cursor = json["data"][1]["meta"]["cursor"] # author2, age 20
              do_index(sort: "-age", page: {after: cursor})
              expect(ids).to eq([author3.id, author1.id])
            end
          end
        end
      end
    end
  end
end
