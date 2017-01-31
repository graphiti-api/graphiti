require 'spec_helper'

RSpec.describe 'sideloading', type: :controller do
  controller(ApplicationController) do
    jsonapi do
      type :authors

      includes whitelist: { index: [{ books: :genre }, :state] }
    end

    def index
      render_jsonapi(Author.all)
    end
  end

  let(:state) { State.create!(name: 'maine') }
  let(:genre) { Genre.create!(name: 'horror') }
  let(:book) { Book.create!(title: 'The Shining', genre: genre) }

  let!(:author) do
    Author.create! \
      first_name: 'Stephen',
      last_name: 'King',
      state: state,
      books: [book]
  end

  it 'sideloads the ?include parameter' do
    get :index, params: { include: 'books,state' }
    expect(json_included_types).to match_array(%w(states books))
  end

  context 'when a custom include function is supplied' do
    before do
      controller.class.class_eval do
        jsonapi do
          includes whitelist: { index: { books: :genre } } do |scope, includes|
            scope.special_include(includes)
          end
        end
      end
    end

    xit 'uses the custom include function' do
      scope = Author.all
      allow(Author).to receive(:all) { scope }

      expect(scope).to receive(:special_include)
        .with(books: { genre: {} }).and_return(scope)

      get :index, params: { include: 'books.genre' }
    end
  end

  context 'when nested includes' do
    it 'sideloads all levels of nesting' do
      get :index, params: { include: 'books.genre,state' }
      expect(json_included_types).to match_array(%w(states genres books))
    end
  end

  context 'when the relation is not whitelisted' do
    it 'silently disregards the relation' do
      get :index, params: { include: 'foo' }
      expect(json).to_not have_key('included')
    end
  end
end
