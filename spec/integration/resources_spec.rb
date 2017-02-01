require 'spec_helper'

RSpec.describe 'integrated resources and adapters', type: :controller do
  module Integration
    class BookResource < JsonapiCompliable::Resource
      type :books
      use_adapter JsonapiCompliable::Adapters::ActiveRecord
      allow_filter :id
    end

    class StateResource < JsonapiCompliable::Resource
      type :states
      use_adapter JsonapiCompliable::Adapters::ActiveRecord
    end

    class BioResource < JsonapiCompliable::Resource
      type :bios
      use_adapter JsonapiCompliable::Adapters::ActiveRecord
    end

    class AuthorResource < JsonapiCompliable::Resource
      type :authors
      use_adapter JsonapiCompliable::Adapters::ActiveRecord

      allow_filter :first_name

      has_many :books,
        foreign_key: :author_id,
        scope: -> { Book.all },
        resource: BookResource

      belongs_to :state,
        foreign_key: :state_id,
        scope: -> { State.all },
        resource: StateResource

      has_one :bio,
        foreign_key: :author_id,
        scope: -> { Bio.all },
        resource: BioResource
    end
  end

  controller(ApplicationController) do
    jsonapi resource: Integration::AuthorResource

    def index
      render_jsonapi(Author.all)
    end
  end

  let!(:author1) { Author.create!(first_name: 'Stephen', state: state) }
  let!(:author2) { Author.create!(first_name: 'George') }
  let!(:book1)   { Book.create!(author: author1, title: 'The Shining') }
  let!(:book2)   { Book.create!(author: author1, title: 'The Stand') }
  let!(:state)   { State.create!(name: 'Maine') }
  let!(:bio)     { Bio.create!(author: author1, picture: 'imgur', description: 'author bio') }

  def book_ids
    json_includes('books').map { |b| b['id'].to_i }
  end

  it 'allows basic sorting' do
    get :index, params: { sort: '-id' }
    expect(json_ids(true)).to eq([author2.id, author1.id])
  end

  it 'allows basic pagination' do
    get :index, params: { page: { number: 2, size: 1 } }
    expect(json_ids(true)).to eq([author2.id])
  end

  it 'allows whitelisted filters (and other configs)' do
    get :index, params: { filter: { first_name: 'George' } }
    expect(json_ids(true)).to eq([author2.id])
  end

  it 'allows basic sideloading' do
    get :index, params: { include: 'books' }
    expect(json_included_types).to match_array(%w(books))
  end

  context 'sideloading has_many' do
    # TODO: may want to blow up here, only for index action
    it 'allows pagination of sideloaded resource' do
      get :index, params: { include: 'books', page: { books: { size: 1, number: 2 } } }
      expect(book_ids).to eq([book2.id])
    end

    it 'allows sorting of sideloaded resource' do
      get :index, params: { include: 'books', sort: '-books.title' }
      expect(book_ids).to eq([book2.id, book1.id])
    end

    it 'allows filtering of sideloaded resource' do
      get :index, params: { include: 'books', filter: { books: { id: book2.id } } }
      expect(book_ids).to eq([book2.id])
    end

    it 'allows extra fields for sideloaded resource' do
      get :index, params: { include: 'books', extra_fields: { books: 'alternate_title' } }
      book = json_includes('books')[0]
      expect(book['title']).to be_present
      expect(book['pages']).to be_present
      expect(book['alternate_title']).to eq('alt title')
    end

    it 'allows sparse fieldsets for the sideloaded resource' do
      get :index, params: { include: 'books', fields: { books: 'pages' } }
      book = json_includes('books')[0]
      expect(book).to_not have_key('title')
      expect(book).to_not have_key('alternate_title')
      expect(book['pages']).to eq(500)
    end
  end

  context 'sideloading belongs_to' do
    it 'allows extra fields for sideloaded resource' do
      get :index, params: { include: 'state', extra_fields: { states: 'population' } }
      state = json_includes('states')[0]
      expect(state['name']).to be_present
      expect(state['abbreviation']).to be_present
      expect(state['population']).to be_present
    end

    it 'allows sparse fieldsets for the sideloaded resource' do
      get :index, params: { include: 'state', fields: { states: 'name' } }
      state = json_includes('states')[0]
      expect(state['name']).to be_present
      expect(state).to_not have_key('abbreviation')
      expect(state).to_not have_key('population')
    end
  end

  context 'sideloading has_one' do
    it 'allows extra fields for sideloaded resource' do
      get :index, params: { include: 'bio', extra_fields: { bios: 'created_at' } }
      bio = json_includes('bios')[0]
      expect(bio['description']).to be_present
      expect(bio['created_at']).to be_present
      expect(bio['picture']).to be_present
    end

    it 'allows sparse fieldsets for the sideloaded resource' do
      get :index, params: { include: 'bio', fields: { bios: 'description' } }
      bio = json_includes('bios')[0]
      expect(bio['description']).to be_present
      expect(bio).to_not have_key('created_at')
      expect(bio).to_not have_key('picture')
    end
  end

  context 'when overriding the resource' do
    before do
      controller.class_eval do
        jsonapi resource: Integration::AuthorResource do
          paginate do |scope, current_page, per_page|
            scope.limit(1)
          end
        end
      end
    end

    it 'respects the override' do
      get :index
      expect(json_ids.length).to eq(1)
    end
  end
end
