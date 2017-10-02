if ENV["APPRAISAL_INITIALIZED"]
  require 'rails_spec_helper'

  RSpec.describe 'integrated resources and adapters', type: :controller do
    let(:genre_resource) do
      Class.new(JsonapiCompliable::Resource) do
        type :genres
        use_adapter JsonapiCompliable::Adapters::ActiveRecord
      end
    end

    let(:book_resource) do
      Class.new(JsonapiCompliable::Resource) do
        type :books
        use_adapter JsonapiCompliable::Adapters::ActiveRecord
        allow_filter :id

        belongs_to :genre,
          scope: -> { Genre.all },
          foreign_key: :genre_id,
          resource: GenreResource
      end
    end

    let(:author_resource) do
      Class.new(JsonapiCompliable::Resource) do
        type :authors
        use_adapter JsonapiCompliable::Adapters::ActiveRecord

        has_many :books,
          scope: -> { Book.all },
          foreign_key: :author_id,
          resource: BookResource
      end
    end

    before do
      stub_const('GenreResource', genre_resource)
      stub_const('BookResource', book_resource)
      stub_const('AuthorResource', author_resource)

      controller.class.jsonapi resource: AuthorResource
    end

    controller(ApplicationController) do
      def index
        render_jsonapi(Author.all)
      end
    end

    def json
      JSON.parse(response.body)
    end

    def json_includes(type)
      json['included'].select { |i| i['type'] == type }
    end

    let!(:author) { Author.create!(first_name: 'Stephen') }
    let!(:book) { Book.create!(title: 'The Shining', author: author, genre: genre) }
    let!(:genre) { Genre.create!(name: 'Horror') }

    context 'when no sideload whitelist' do
      it 'allows loading all relationships' do
        get :index, params: { include: 'books.genre' }
        expect(json_includes('books')).to_not be_blank
        expect(json_includes('genres')).to_not be_blank
      end
    end

    context 'when a sideload whitelist' do
      before do
        controller.class.sideload_whitelist({
          index: [:books],
          show: { books: :genre }
        })
      end

      it 'restricts what sideloads can be loaded' do
        get :index, params: { include: 'books.genre' }
        expect(json_includes('books')).to_not be_blank
        expect(json_includes('genres')).to be_blank
      end
    end
  end
end
