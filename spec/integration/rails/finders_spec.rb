if ENV["APPRAISAL_INITIALIZED"]
  require 'rails_spec_helper'

  RSpec.describe 'integrated resources and adapters', type: :controller do
    module Integration
      class GenreResource < JsonapiCompliable::Resource
        type :genres
        use_adapter JsonapiCompliable::Adapters::ActiveRecord
      end

      class BookResource < JsonapiCompliable::Resource
        type :books
        use_adapter JsonapiCompliable::Adapters::ActiveRecord
        allow_filter :id

        belongs_to :genre,
          scope: -> { Genre.all },
          foreign_key: :genre_id,
          resource: GenreResource
      end

      class StateResource < JsonapiCompliable::Resource
        type :states
        use_adapter JsonapiCompliable::Adapters::ActiveRecord
      end

      class DwellingResource < JsonapiCompliable::Resource
        type :dwellings
        use_adapter JsonapiCompliable::Adapters::ActiveRecord

        belongs_to :state,
          foreign_key: :state_id,
          scope: -> { State.all },
          resource: StateResource
      end

      class BioResource < JsonapiCompliable::Resource
        type :bios
        use_adapter JsonapiCompliable::Adapters::ActiveRecord
      end

      class HobbyResource < JsonapiCompliable::Resource
        type :hobbies
        allow_filter :id
        use_adapter JsonapiCompliable::Adapters::ActiveRecord
      end

      class OrganizationResource < JsonapiCompliable::Resource
        type :organizations
        use_adapter JsonapiCompliable::Adapters::ActiveRecord

        has_many :children,
          foreign_key: :parent_id,
          resource: OrganizationResource,
          scope: -> { Organization.all }
        belongs_to :parent,
          foreign_key: :parent_id,
          resource: OrganizationResource,
          scope: -> { Organization.all }
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

        has_and_belongs_to_many :hobbies,
          resource: HobbyResource,
          scope: -> { Hobby.all },
          foreign_key: { author_hobbies: :author_id }

        polymorphic_belongs_to :dwelling,
          group_by: :dwelling_type,
          groups: {
            'House' => {
              foreign_key: :dwelling_id,
              resource: DwellingResource,
              scope: -> { House.all }
            },
            'Condo' => {
              foreign_key: :dwelling_id,
              resource: DwellingResource,
              scope: -> { Condo.all }
            }
          }

        belongs_to :organization,
          foreign_key: :organization_id,
          resource: OrganizationResource,
          scope: -> { Organization.all }
      end
    end

    controller(ApplicationController) do
      jsonapi resource: Integration::AuthorResource

      def index
        render_jsonapi(Author.all)
      end
    end

    let!(:author1) { Author.create!(first_name: 'Stephen', dwelling: house, state: state, organization: org1) }
    let!(:author2) { Author.create!(first_name: 'George', dwelling: condo) }
    let!(:book1)   { Book.create!(author: author1, genre: genre, title: 'The Shining') }
    let!(:book2)   { Book.create!(author: author1, genre: genre, title: 'The Stand') }
    let!(:state)   { State.create!(name: 'Maine') }
    let!(:bio)     { Bio.create!(author: author1, picture: 'imgur', description: 'author bio') }
    let!(:hobby1)  { Hobby.create!(name: 'Fishing', authors: [author1]) }
    let!(:hobby2)  { Hobby.create!(name: 'Woodworking', authors: [author1, author2]) }
    let(:house)    { House.new(name: 'Cozy', state: state) }
    let(:condo)    { Condo.new(name: 'Modern', state: state) }
    let(:genre)    { Genre.create!(name: 'Horror') }
    let(:org1)     { Organization.create!(name: 'Org1', children: [org2]) }
    let(:org2)     { Organization.create!(name: 'Org2') }

    def ids_for(type)
      json_includes(type).map { |i| i['id'].to_i }
    end

    def json_included_types
      json['included'].map { |i| i['type'] }.uniq
    end

    def json_includes(type)
      json['included'].select { |i| i['type'] == type }
    end

    def json_ids
      json['data'].map { |d| d['id'].to_i }
    end

    def json
      JSON.parse(response.body)
    end

    it 'allows basic sorting' do
      include Rails.application.routes.url_helpers
      get :index, params: { sort: '-id' }
      expect(json_ids).to eq([author2.id, author1.id])
    end

    it 'allows basic pagination' do
      get :index, params: { page: { number: 2, size: 1 } }
      expect(json_ids).to eq([author2.id])
    end

    it 'allows whitelisted filters (and other configs)' do
      get :index, params: { filter: { first_name: 'George' } }
      expect(json_ids).to eq([author2.id])
    end

    it 'allows basic sideloading' do
      get :index, params: { include: 'books' }
      expect(json_included_types).to match_array(%w(books))
    end

    it 'allows nested sideloading' do
      get :index, params: { include: 'books.genre' }
      expect(json_included_types).to match_array(%w(books genres))
    end

    context 'sideloading has_many' do
      # TODO: may want to blow up here, only for index action
      it 'allows pagination of sideloaded resource' do
        get :index, params: { include: 'books', page: { books: { size: 1, number: 2 } } }
        expect(ids_for('books')).to eq([book2.id])
      end

      it 'allows sorting of sideloaded resource' do
        get :index, params: { include: 'books', sort: '-books.title' }
        expect(ids_for('books')).to eq([book2.id, book1.id])
      end

      it 'allows filtering of sideloaded resource' do
        get :index, params: { include: 'books', filter: { books: { id: book2.id } } }
        expect(ids_for('books')).to eq([book2.id])
      end

      it 'allows extra fields for sideloaded resource' do
        get :index, params: { include: 'books', extra_fields: { books: 'alternate_title' } }
        book = json_includes('books')[0]['attributes']
        expect(book['title']).to be_present
        expect(book['pages']).to be_present
        expect(book['alternate_title']).to eq('alt title')
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'books', fields: { books: 'pages' } }
        book = json_includes('books')[0]['attributes']
        expect(book).to_not have_key('title')
        expect(book).to_not have_key('alternate_title')
        expect(book['pages']).to eq(500)
      end
    end

    context 'sideloading belongs_to' do
      it 'allows extra fields for sideloaded resource' do
        get :index, params: { include: 'state', extra_fields: { states: 'population' } }
        state = json_includes('states')[0]['attributes']
        expect(state['name']).to be_present
        expect(state['abbreviation']).to be_present
        expect(state['population']).to be_present
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'state', fields: { states: 'name' } }
        state = json_includes('states')[0]['attributes']
        expect(state['name']).to be_present
        expect(state).to_not have_key('abbreviation')
        expect(state).to_not have_key('population')
      end
    end

    context 'sideloading has_one' do
      it 'allows extra fields for sideloaded resource' do
        get :index, params: { include: 'bio', extra_fields: { bios: 'created_at' } }
        bio = json_includes('bios')[0]['attributes']
        expect(bio['description']).to be_present
        expect(bio['created_at']).to be_present
        expect(bio['picture']).to be_present
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'bio', fields: { bios: 'description' } }
        bio = json_includes('bios')[0]['attributes']
        expect(bio['description']).to be_present
        expect(bio).to_not have_key('created_at')
        expect(bio).to_not have_key('picture')
      end
    end

    context 'sideloading has_and_belongs_to_many' do
      it 'allows sorting of sideloaded resource' do
        get :index, params: { include: 'hobbies', sort: '-hobbies.name' }
        expect(ids_for('hobbies')).to eq([hobby2.id, hobby1.id])
      end

      it 'allows filtering of sideloaded resource' do
        get :index, params: { include: 'hobbies', filter: { hobbies: { id: hobby2.id } } }
        expect(ids_for('hobbies')).to eq([hobby2.id])
      end

      it 'allows extra fields for sideloaded resource' do
        get :index, params: { include: 'hobbies', extra_fields: { hobbies: 'reason' } }
        hobby = json_includes('hobbies')[0]['attributes']
        expect(hobby['name']).to be_present
        expect(hobby['description']).to be_present
        expect(hobby['reason']).to eq('hobby reason')
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'hobbies', fields: { hobbies: 'name' } }
        hobby = json_includes('hobbies')[0]['attributes']
        expect(hobby['name']).to be_present
        expect(hobby).to_not have_key('description')
        expect(hobby).to_not have_key('reason')
      end

      it 'does not duplicate results' do
        get :index, params: { include: 'hobbies' }
        author1_relationships = json['data'][0]['relationships']
        author2_relationships = json['data'][1]['relationships']

        author1_hobbies = author1_relationships['hobbies']['data']
        author2_hobbies = author2_relationships['hobbies']['data']

        expect(json_includes('hobbies').size).to eq(2)
        expect(author1_hobbies.size).to eq(2)
        expect(author2_hobbies.size).to eq(1)
      end
    end

    context 'sideloading self-referential' do
      it 'works' do
        get :index, params: { include: 'organization.children' }
        includes = json_includes('organizations')
        expect(includes[0]['attributes']['name']).to eq('Org1')
        expect(includes[1]['attributes']['name']).to eq('Org2')
      end
    end

    context 'sideloading the same "type", then adding another sideload' do
      before do
        Author.class_eval do
          has_many :other_books, class_name: 'Book'
        end

        SerializableAuthor.class_eval do
          has_many :other_books
        end

        Integration::AuthorResource.class_eval do
          has_many :other_books,
            scope: -> { Book.all },
            foreign_key: :author_id,
            resource: Integration::BookResource
        end
      end

      it 'works' do
        book2.genre = Genre.create! name: 'Comedy'
        book2.save!
        get :index, params: {
          filter: { books: { id: book1.id }, other_books: { id: book2.id } },
          include: 'books.genre,other_books.genre'
        }
        expect(json_includes('genres').length).to eq(2)
      end
    end

    context 'sideloading polymorphic belongs_to' do
      it 'allows extra fields for the sideloaded resource' do
        get :index, params: {
          include: 'dwelling',
          extra_fields: { houses: 'house_price', condos: 'condo_price' }
        }
        house = json_includes('houses')[0]['attributes']
        expect(house['name']).to be_present
        expect(house['house_description']).to be_present
        expect(house['house_price']).to eq(1_000_000)
        condo = json_includes('condos')[0]['attributes']
        expect(condo['name']).to be_present
        expect(condo['condo_description']).to be_present
        expect(condo['condo_price']).to eq(500_000)
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: {
          include: 'dwelling',
          fields: { houses: 'name', condos: 'condo_description' }
        }
        house = json_includes('houses')[0]['attributes']
        expect(house['name']).to be_present
        expect(house).to_not have_key('house_description')
        expect(house).to_not have_key('house_price')
        condo = json_includes('condos')[0]['attributes']
        expect(condo['condo_description']).to be_present
        expect(condo).to_not have_key('name')
        expect(condo).to_not have_key('condo_price')
      end

      it 'allows additional levels of nesting' do
        get :index, params: { include: 'dwelling.state' }
        expect(json_includes('states').length).to eq(1)
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
end
