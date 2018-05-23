require 'spec_helper'

RSpec.describe 'sideloading' do
  include_context 'scoping'

  let(:ar_resource) do
    Class.new(JsonapiCompliable::Resource) do
      use_adapter JsonapiCompliable::Adapters::ActiveRecord
    end
  end

  let(:book_resource) do
    book_resource_klass = Class.new(ar_resource) do
      type :books
      allow_filter :id
    end

    book_resource_klass.allow_sideload :genre, resource: genre_resource do
      scope do |books|
        Genre.where(id: books.map(&:genre_id))
      end

      assign do |books, genres|
        books.each do |book|
          book.instance_variable_set(:@the_genre, genres.find { |g| g.id == book.genre_id })
        end
      end
    end

    book_resource_klass
  end

  let(:genre_resource) do
    Class.new(ar_resource) do
      type :genres
    end
  end

  let(:state_resource) do
    Class.new(ar_resource) do
      type :states
    end
  end

  let(:dwelling_resource) do
    Class.new(ar_resource) do
      type :dwellings
    end
  end

  let(:scope_object) do
    Author.all.map do |a|
      a.attributes.symbolize_keys
        .slice(:id, :state_id, :dwelling_id, :dwelling_type)
    end
  end

  before do
    resource_class.use_adapter JsonapiCompliable::Adapters::Null
    resource_class.allow_sideload :books, resource: book_resource do
      scope do |authors|
        Book.where(author_id: authors.map { |a| a[:id] })
      end

      assign do |authors, books|
        authors.each do |author|
          author[:books] = books.select { |b| b.author_id == author[:id] }
        end
      end
    end

    resource_class.allow_sideload :one_book, resource: book_resource do
      scope do |authors|
        Book.limit(1)
      end

      assign do |authors, books|
        authors.each do |author|
          author[:books] = books
        end
      end
    end

    resource_class.allow_sideload :state, resource: state_resource do
      scope do |authors|
        State.where(id: authors.map { |a| a[:state_id] })
      end

      assign do |authors, states|
        authors.each do |author|
          author[:state] = states.find { |s| s.id == author[:state_id] }
        end
      end
    end

    _dwelling_resource = dwelling_resource
    resource_class.allow_sideload :dwelling, polymorphic: true do
      group_by :dwelling_type

      allow_sideload 'House', resource: _dwelling_resource do
        scope do |authors|
          House.where(id: authors.map { |a| a[:dwelling_id] })
        end

        assign do |authors, houses|
          authors.each do |author|
            author[:dwelling] = houses.find { |h| h.id == author[:dwelling_id] }
          end
        end
      end

      allow_sideload 'Condo', resource: _dwelling_resource do
        scope do |authors|
          Condo.where(id: authors.map { |a| a[:dwelling_id] })
        end

        assign do |authors, condos|
          authors.each do |author|
            author[:dwelling] = condos.find { |c| c.id == author[:dwelling_id] }
          end
        end
      end
    end
  end

  let!(:state)  { State.create!(name: 'maine') }
  let!(:genre)  { Genre.create!(name: 'horror') }
  let!(:book1)  { Book.create!(title: 'The Shining', author: author, genre: genre) }
  let!(:book2)  { Book.create!(title: 'The Stand', author: author, genre: genre) }

  let!(:author) do
    Author.create! \
      first_name: 'Stephen',
      last_name: 'King',
      state: state
  end

  def json
    authors = scope.resolve.map { |a| Author.new(a) }
    render(authors)
  end

  it 'sideloads correctly using scope/assign procs' do
    params[:include] = 'books'
    author = scope.resolve.first
    expect(author[:books]).to eq([book1, book2])
  end

  it 'supports filtering associations' do
    params[:include] = 'books'
    params[:filter]  = { books: { id: book2.id } }
    expect(scope.resolve.first[:books]).to eq([book2])
  end

  it 'supports paginating associations' do
    params[:include] = 'books'
    params[:page]   = { books: { size: 1, number: 2 } }
    expect(scope.resolve.first[:books]).to eq([book2])
  end

  it 'does not apply default pagination for sideloads' do
    params[:include] = 'one_book'
    expect(scope.resolve.first[:books]).to eq([book1])
  end

  it 'supports sorting associations' do
    params[:include] = 'books'
    params[:sort]    = '-books.title'
    expect(scope.resolve.first[:books]).to eq([book2, book1])
  end

  it 'supports extra fields of sideloaded resource' do
    params[:include]      = 'state'
    params[:extra_fields] = { states: 'population' }

    state = json['included'][0]['attributes']
    expect(state['population']).to eq(10_000)
    expect(state['abbreviation']).to_not be_nil
    expect(state['name']).to_not be_nil
  end

  it 'supports sparse fielset of sideloaded resource' do
    params[:include] = 'state'
    params[:fields] = { states: 'name' }

    state = json['included'][0]['attributes']
    expect(state['name']).to_not be_nil
    expect(state).to_not have_key('abbreviation')
    expect(state).to_not have_key('population')
  end

  context 'when the sideload is polymorphic' do
    let!(:condo)        { Condo.create!(name: 'My Condo') }
    let!(:condo_author) { Author.create!(dwelling: condo) }
    let!(:house)        { House.create!(name: 'Cozy House') }

    before do
      author.dwelling = house
      author.save!

      _dwelling_resource = dwelling_resource
      resource_class.allow_sideload :dwelling, polymorphic: true do
        group_by :dwelling_type

        allow_sideload 'House', resource: _dwelling_resource do
          scope do |authors|
            House.where(id: authors.map { |a| a[:dwelling_id] })
          end

          assign do |authors, houses|
            authors.each do |author|
              author[:dwelling] = houses.find { |h| h.id == author[:dwelling_id] }
            end
          end
        end

        allow_sideload 'Condo', resource: _dwelling_resource do
          scope do |authors|
            Condo.where(id: authors.map { |a| a[:dwelling_id] })
          end

          assign do |authors, condos|
            authors.each do |author|
              author[:dwelling] = condos.find { |c| c.id == author[:dwelling_id] }
            end
          end
        end
      end
    end

    it 'groups by type' do
      params[:include] = 'dwelling'
      authors = scope.resolve
      expect(authors[0][:id]).to eq(author.id)
      expect(authors[0][:dwelling]).to eq(house)
      expect(authors[1][:id]).to eq(condo_author.id)
      expect(authors[1][:dwelling]).to eq(condo)
    end

    it 'supports extra_fields for each type' do
      params[:include] = 'dwelling'
      params[:extra_fields] = { condos: 'condo_price', houses: 'house_price' }

      house = json['included'].find { |i| i['type'] == 'houses' }
      house = house['attributes']
      expect(house['name']).to_not be_nil
      expect(house['house_description']).to_not be_nil
      expect(house['house_price']).to eq(1_000_000)
      condo = json['included'].find { |i| i['type'] == 'condos' }
      condo = condo['attributes']
      expect(condo['name']).to_not be_nil
      expect(condo['condo_description']).to_not be_nil
      expect(condo['condo_price']).to eq(500_000)
    end

    it 'supports sparse fieldsets for each type' do
      params[:include] = 'dwelling'
      params[:fields] = { condos: 'name', houses: 'name' }

      house = json['included'].find { |i| i['type'] == 'houses' }
      house = house['attributes']
      expect(house['name']).to_not be_nil
      expect(house).to_not have_key('house_description')
      expect(house).to_not have_key('price')
      condo = json['included'].find { |i| i['type'] == 'condos' }
      condo = condo['attributes']
      expect(condo['name']).to_not be_nil
      expect(condo).to_not have_key('condo_description')
      expect(condo).to_not have_key('condo_price')
    end
  end

  context 'when nested includes' do
    it 'sideloads all levels of nesting' do
      params[:include] = 'books.genre,state'
      author = scope.resolve.first
      expect(author[:books]).to eq([book1, book2])
      expect(author[:books][0].instance_variable_get(:@the_genre)).to eq(genre)
    end
  end


  context 'when sideload has required filter' do
    before do
      a = author
      book_resource.class_eval do
        allow_filter :required, required: true do |scope, value|
          scope.where(author_id: a.id)
        end
      end
    end

    context 'and no required filters are provided' do
      before do
        params[:include] = 'books'
      end

      it 'raises an error' do
        expect {
          scope.resolve
        }.to raise_error(JsonapiCompliable::Errors::RequiredFilter, 'The required filter "required" was not provided')
      end

    end

    context 'and sideloaded filter is provided with symbolized keys' do
      before do
        params[:include] = 'books'
        params[:filter] = { books: {required: true} }
      end

      it 'should return results' do
        author = scope.resolve.first
        expect(author[:books]).to eq([book1, book2])
      end
    end

    context 'and sideloaded filter is provided with stringified keys' do
      before do
        params[:include] = 'books'
        params[:filter] = { 'books' => {'required' => true} }
      end

      it 'should return results' do
        author = scope.resolve.first
        expect(author[:books]).to eq([book1, book2])
      end
    end
  end
end
