require 'spec_helper'

RSpec.describe 'sideloading', type: :controller do
  controller(ApplicationController) do
    jsonapi do
      type :authors
      use_adapter JsonapiCompliable::Adapters::Null

      class BookResource < JsonapiCompliable::Resource
        type :books
        allow_filter :id
        use_adapter JsonapiCompliable::Adapters::ActiveRecord
      end

      class StateResource < JsonapiCompliable::Resource
        type :states
        use_adapter JsonapiCompliable::Adapters::ActiveRecord
      end

      allow_sideload :books, resource: BookResource do
        scope do |authors|
          Book.where(author_id: authors.map { |a| a[:id] })
        end

        assign do |authors, books|
          authors.each do |author|
            author[:books] = books.select { |b| b.author_id == author[:id] }
          end
        end

        allow_sideload :genre do
          scope do |books|
            Genre.where(id: books.map(&:genre_id))
          end

          assign do |books, genres|
            books.each do |book|
              book.genre = genres.find { |g| g.id == book.genre_id }
            end
          end
        end
      end

      allow_sideload :state, resource: StateResource do
        scope do |authors|
          State.where(id: authors.map { |a| a[:id] })
        end

        assign do |authors, states|
          authors.each do |author|
            author[:state] = states.find { |s| s.id == author[:state_id] }
          end
        end
      end

      allow_sideload :bio

      sideload_whitelist({ index: [{ books: :genre }, :state] })
    end

    # Scope via hashes, so we don't get any ActiveRecord false-positives
    # Then create actual authors from the results, for serialization
    def index
      author_hashes = Author.all.map { |a| { id: a.id, state_id: a.state_id } }
      scope         = jsonapi_scope(author_hashes)
      authors       = scope.resolve.map do |attrs|
        author = Author.new(attrs.except(:books))
        author.association(:books).loaded! # avoid AR db query
        attrs[:books].each do |b|
          author.association(:books).add_to_target(b)
        end if attrs[:books]
        author
      end
      render_jsonapi(authors, scope: false)
    end
  end

  let(:state)  { State.create!(name: 'maine') }
  let(:genre)  { Genre.create!(name: 'horror') }
  let(:book1)  { Book.create!(title: 'The Shining', genre: genre) }
  let(:book2)  { Book.create!(title: 'The Stand', genre: genre) }

  let!(:author) do
    Author.create! \
      first_name: 'Stephen',
      last_name: 'King',
      state: state,
      books: [book1, book2]
  end

  it 'sideloads the ?include parameter' do
    get :index, params: { include: 'books,state' }
    expect(json_included_types).to match_array(%w(states books))
  end

  it 'supports filtering associations' do
    get :index, params: { include: 'books', filter: { books: { id: book2.id } } }
    expect(json_includes('books').map { |b| b['id'].to_i }).to eq([book2.id])
  end

  it 'supports paginating associations' do
    get :index, params: { include: 'books', page: { books: { size: 1, number: 2 } } }
    expect(json_includes('books').map { |b| b['id'].to_i }).to eq([book2.id])
  end

  it 'supports sorting associations' do
    get :index, params: { include: 'books', sort: '-books.title' }
    expect(json_includes('books').map { |b| b['id'].to_i }).to eq([book2.id, book1.id])
  end

  it 'supports extra fields of sideloaded resource' do
    get :index, params: { include: 'state', extra_fields: { states: 'population' } }

    state = json_includes('states')[0]
    expect(state['population']).to eq(10_000)
    expect(state['abbreviation']).to_not be_nil
    expect(state['name']).to_not be_nil
  end

  it 'supports sparse fielset of sideloaded resource' do
    get :index, params: { include: 'state', fields: { states: 'name' } }

    state = json_includes('states')[0]
    expect(state['name']).to_not be_nil
    expect(state).to_not have_key('abbreviation')
    expect(state).to_not have_key('population')
  end

  context 'when nested includes' do
    it 'sideloads all levels of nesting' do
      get :index, params: { include: 'books.genre,state' }
      expect(json_included_types).to match_array(%w(states genres books))
    end
  end

  context 'when the relation is not whitelisted' do
    it 'silently disregards the relation' do
      get :index, params: { include: 'bio' }
      expect(json).to_not have_key('included')
    end
  end
end
