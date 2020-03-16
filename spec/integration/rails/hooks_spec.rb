if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "persistence lifecycle hooks", type: :controller do
    class Callbacks
      class << self
        attr_reader :fired
      end

      class << self
        attr_writer :fired
      end
    end

    before do
      Callbacks.fired = {}
    end

    module IntegrationHooks
      class ApplicationResource < Graphiti::Resource
        self.adapter = Graphiti::Adapters::ActiveRecord
      end

      class BookResource < ApplicationResource
        self.model = Legacy::Book
        attribute :author_id, :integer, only: [:writable]
        attribute :title, :string
      end

      class StateResource < ApplicationResource
        self.model = Legacy::State
        attribute :name, :string
      end

      class AuthorResource < ApplicationResource
        self.model = Legacy::Author

        attribute :first_name, :string
        attribute :last_name, :string

        has_many :books,
          resource: BookResource do
            after_save only: [:create] do |author, books|
              Callbacks.fired[:after_create] = [author, books]
            end

            after_save only: [:update] do |author, books|
              Callbacks.fired[:after_update] = [author, books]
            end

            after_save only: [:destroy] do |author, books|
              Callbacks.fired[:after_destroy] = [author, books]
            end

            after_save only: [:disassociate] do |author, books|
              Callbacks.fired[:after_disassociate] = [author, books]
            end

            after_save do |author, books|
              Callbacks.fired[:after_save] = [author, books]
            end
          end

        belongs_to :state,
          resource: StateResource do
            after_save only: [:create] do |author, states|
              Callbacks.fired[:state_after_create] = [author, states]
            end
          end
      end
    end

    controller(ApplicationController) do
      def create
        author = IntegrationHooks::AuthorResource.build(params)

        if author.save
          render jsonapi: author
        else
          raise "whoops"
        end
      end

      private

      def params
        @params ||= begin
          hash = super.to_unsafe_h.with_indifferent_access
          hash = hash[:params] if hash.key?(:params)
          hash
        end
      end
    end

    before do
      @request.headers["Accept"] = Mime[:json]
      @request.headers["Content-Type"] = Mime[:json].to_s

      routes.draw {
        post "create" => "anonymous#create"
      }
    end

    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with("PATH_INFO") { path }
    end

    let(:path) { "/integration_hooks/authors" }

    def json
      JSON.parse(response.body)
    end

    let(:update_book) { Legacy::Book.create! }
    let(:destroy_book) { Legacy::Book.create! }
    let(:disassociate_book) { Legacy::Book.create! }

    let(:book_data) { [] }
    let(:book_included) { [] }
    let(:state_data) { nil }
    let(:state_included) { [] }

    let(:payload) do
      {
        data: {
          type: "authors",
          attributes: {first_name: "Stephen", last_name: "King"},
          relationships: {
            books: {data: book_data},
            state: {data: state_data}
          }
        },
        included: (book_included + state_included)
      }
    end

    context "after_save" do
      before do
        book_data << {'temp-id': "abc123", type: "books", method: "create"}
        book_included << {'temp-id': "abc123", type: "books", attributes: {title: "one"}}
        book_data << {id: update_book.id.to_s, type: "books", method: "update"}
        book_included << {id: update_book.id.to_s, type: "books", attributes: {title: "updated!"}}
      end
    end

    context "after_create" do
      before do
        book_data << {'temp-id': "abc123", type: "books", method: "create"}
        book_included << {'temp-id': "abc123", type: "books", attributes: {title: "one"}}
        book_data << {'temp-id': "abc456", type: "books", method: "create"}
        book_included << {'temp-id': "abc456", type: "books", attributes: {title: "two"}}
      end

      it "fires hooks correctly" do
        do_create(payload)

        expect(Callbacks.fired.keys).to match_array([:after_create, :after_save])
        author, books = Callbacks.fired[:after_create]
        expect(author).to be_a(Legacy::Author)
        expect(author.first_name).to eq("Stephen")
        expect(author.last_name).to eq("King")

        expect(books).to all(be_a(Legacy::Book))
        expect(books.map(&:title)).to match_array(%w[one two])
      end
    end

    context "after_update" do
      before do
        book_data << {id: update_book.id.to_s, type: "books", method: "update"}
        book_included << {id: update_book.id.to_s, type: "books", attributes: {title: "updated!"}}
      end

      it "fires hooks correctly" do
        do_create(payload)

        expect(Callbacks.fired.keys)
          .to match_array([:after_update, :after_save])
        author, books = Callbacks.fired[:after_update]
        expect(author).to be_a(Legacy::Author)
        expect(author.first_name).to eq("Stephen")
        expect(author.last_name).to eq("King")

        book = books[0]
        expect(book.title).to eq("updated!")
      end
    end

    context "after_destroy" do
      before do
        book_data << {id: destroy_book.id.to_s, type: "books", method: "destroy"}
      end

      it "fires hooks correctly" do
        do_create(payload)

        expect(Callbacks.fired.keys).to match_array([:after_destroy, :after_save])
        author, books = Callbacks.fired[:after_destroy]
        expect(author).to be_a(Legacy::Author)
        expect(author.first_name).to eq("Stephen")
        expect(author.last_name).to eq("King")

        book = books[0]
        expect(book).to be_a(Legacy::Book)
        expect(book.id).to eq(destroy_book.id)
        expect { book.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "after_disassociate" do
      before do
        book_data << {id: disassociate_book.id.to_s, type: "books", method: "disassociate"}
      end

      it "fires hooks correctly" do
        do_create(payload)

        expect(Callbacks.fired.keys).to match_array([:after_disassociate, :after_save])
        author, books = Callbacks.fired[:after_disassociate]
        expect(author).to be_a(Legacy::Author)
        expect(author.first_name).to eq("Stephen")
        expect(author.last_name).to eq("King")

        book = books[0]
        expect(book).to be_a(Legacy::Book)
        expect(book.id).to eq(disassociate_book.id)
        expect(book.author_id).to be_nil
      end
    end

    context "belongs_to" do
      let(:state_data) { {'temp-id': "abc123", type: "states", method: "create"} }

      before do
        state_included << {'temp-id': "abc123", type: "states", attributes: {name: "New York"}}
      end

      it "also works" do
        do_create(payload)

        expect(Callbacks.fired.keys).to match_array([:state_after_create])
        author, states = Callbacks.fired[:state_after_create]
        state = states[0]
        expect(author).to be_a(Legacy::Author)
        expect(author.first_name).to eq("Stephen")
        expect(author.last_name).to eq("King")
        expect(state).to be_a(Legacy::State)
        expect(state.name).to eq("New York")
      end
    end
  end
end
