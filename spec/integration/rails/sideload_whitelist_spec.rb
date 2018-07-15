if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe 'sideload whitelist', type: :controller do
    controller(ApplicationController) do
      def index
        render jsonapi: Legacy::AuthorResource.all(params)
      end
    end

    def json
      JSON.parse(response.body)
    end

    def json_includes(type)
      json['included'].select { |i| i['type'] == type }
    end

    let!(:author) { Legacy::Author.create!(first_name: 'Stephen') }
    let!(:book) { Legacy::Book.create!(title: 'The Shining', author: author, genre: genre) }
    let!(:genre) { Legacy::Genre.create!(name: 'Horror') }

    context 'when no sideload whitelist' do
      it 'allows loading all relationships' do
        get :index, params: { include: 'books.genre' }
        expect(json_includes('books')).to_not be_blank
        expect(json_includes('genres')).to_not be_blank
      end
    end

    context 'when a sideload whitelist' do
      before do
        controller.class.sideload_whitelist = {
          index: [:books],
          show: { books: :genre }
        }
      end

      it 'restricts what sideloads can be loaded' do
        get :index, params: { include: 'books.genre' }
        expect(json_includes('books')).to_not be_blank
        expect(json_includes('genres')).to be_blank
      end
    end
  end
end
