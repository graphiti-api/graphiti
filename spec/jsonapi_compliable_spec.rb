require 'spec_helper'

RSpec.describe JSONAPICompliable, type: :controller do
  controller(ActionController::Base) do
    include JSONAPICompliable
    attr_accessor :serializer

    jsonapi do
      includes whitelist: { index: [{ books: :genre }, :state] }

      allow_filter :first_name, aliases: [:title], if: :can_filter_first_name?
      allow_filter :first_name_prefix do |scope, filter|
        scope.where('first_name like ?', "#{filter}%")
      end
    end

    before_action :deserialize_jsonapi!, only: [:create, :update]

    def index
      scope = Author.all
      render_ams(scope)
    end

    def create;end
    def update;end

    def current_user; end

    def can_filter_first_name?
      true
    end

    def default_page_size
      20
    end
  end

  let!(:virginia) { State.create(name: 'Virginia') }
  let!(:newyork)  { State.create(name: 'New York') }
  let!(:mystery)  { Genre.create(name: 'Mystery') }
  context 'when creating' do
    before do
      controller.class_eval do
        def create
          author = Author.new(params.require(:author).permit!)
          author.save!(validate: false)
          render_ams(author)
        end
      end
    end

    it 'should include whatever nested relations sent in request in response' do
      post :create, params: {
        data: {
          type: 'authors',
          attributes: { first_name: 'Stephen', last_name: 'King' },
          relationships: {
            state: {
              data: {
                type: 'states',
                id: virginia.id
              }
            },
            books: {
              data: [
                { type: 'books', attributes: { title: 'The Shining' } }
              ]
            }
          }
        }
      }

      expect(json_included_types)
        .to match_array(%w(states books))
      expect(json_include('states')['id'])
        .to eq(virginia.id.to_s)
      expect(json_include('states')['id']).to eq(virginia.id.to_s)
    end
  end

  it 'should be able to override options' do
    author = Author.create!(first_name: 'Stephen',last_name: 'King', state_attributes: { id: virginia.id })
    author.books.create(title: "The Shining", genre_attributes: { id: mystery.id })

    controller.class_eval do
      def index
        scope = Author.all
        render_ams(scope, include: [ :state, { books: :genre }])
      end
    end

    get :index

    expect(json_included_types).to match_array(%w(books genres states))
  end
  context 'when updating' do
    let!(:author) { Author.create!(first_name: 'Stephen', last_name: 'King', state_attributes: { id: virginia.id }) }
    let!(:old_book) { author.books.create(title: "The Shining") }

    before do
      routes.draw { put "update" => "anonymous#update" }

      controller.class_eval do
        def update
          author = Author.find(params[:author][:id])
          author.update_attributes!(params.require(:author).permit!)
          render_ams(author)
        end
      end
    end

    it 'should only include relations send as part of payload' do
      put :update, id: author.id, params: {
        data: {
          id: author.id,
          type: 'authors',
          relationships: {
            books: {
              data: [
                {
                  type: 'books',
                  attributes: {
                     title: "The Firm",
                     genre_attributes: {
                      name: "Thriller"
                    }
                  }
                 }
              ]
            }
          }
        }
      }

      expect(json_included_types).to match_array(%w(books))
      expect(json_include('books')['id']).to eq(Book.last.id.to_s)
      author.reload
      expect(author.book_ids).to match_array(Book.pluck(:id))
    end
  end

  it 'should apply default pagination when no page param present' do
    3.times { |r| Author.create!(first_name: "first#{r}", last_name: "last#{r}",state: State.last) }
    allow(controller).to receive(:default_page_size) { 2 }

    get :index
    expect(json_items.length).to eq(2)
  end

  it 'should default sort to id asc' do
    Author.create!(first_name: "First", state: State.last)
    Author.create!(first_name: "Second", state: State.last)
    get :index
    expect(json_ids(true)).to eq(Author.pluck(:id))
  end

  it 'should be able to override options' do
    author = Author.create!(first_name: 'Stephen', last_name: 'King', state_attributes: { id: virginia.id })
    author.books.create(title: "The Shining", genre_attributes: { id: mystery.id })

    controller.class_eval do
      def index
        scope = Author.all
        render_ams(scope, include: { books: :genre })
      end
    end

    get :index
    expect(json_included_types).to match_array(%w(books genres))
    #assert_record_payload(:book, author.book, json_include('stages'))
    #assert_record_payload(:stage_type, server.stage.type, json_include('stage_types'))
  end

  context 'when including relations' do
    it 'only allows valid include params' do
      scope = double(is_a?: true).as_null_object
      expect(scope).to receive(:includes).with(state: {})
        .and_return(scope)
      allow(Author).to receive(:all) { scope }

      get :index, params: { include: 'state,foo' }
    end

    it 'merges default AMS options' do
      allow(controller).to receive(:default_ams_options) {
        { adapter: :attributes }
      }

      expect(controller).to receive(:render)
        .with(
          json: anything,
          adapter: :attributes,
          include: { books: { genre: {} } }
      ).and_call_original
      get :index, params: { include: 'books.genre,foo' }
    end

    context 'and a custom include function is given' do
      before do
        controller.class_eval do
          jsonapi do
            includes whitelist: { index: { books: :genre } }  do |scope, includes|
              scope.special_include(includes)
            end
          end
        end
      end

      it 'should use the custom function' do
        scope = double(is_a?: true).as_null_object
        expect(Author).to receive(:all) { scope }
        expect(scope).to receive(:special_include).with(books: { genre: {} }).and_return(scope)
        get :index, params: { include: 'books.genre,foo' }
      end
    end
  end

  context 'when manually applying scopes' do
    before do
      controller.class_eval do
        def index
          people = jsonapi_scope(Author.all).to_a
          render_ams(people)
        end
      end
    end

    let!(:author) { Author.create!(first_name: 'Stephen', last_name: 'King', state_attributes: { id: virginia.id }) }
    let!(:book) { author.books.create(title: "The Shining") }

    it 'should not re-apply scopes' do
      expect(controller).to receive(:jsonapi_scope)
        .once
        .and_call_original
      get :index
      expect(json_items(0)['first-name']).to eq('Stephen')
    end
  end

  context 'when sorting' do
    before do
      Author.create!(first_name: 'Philip', last_name: 'Roth',state_attributes: { id: newyork.id })
      Author.create!(first_name: 'Stephen',   last_name: 'King', state_attributes: { id: virginia.id })
    end

    subject do
      get :index, params: { sort: sort_param }
      json_items.map { |n| n['first-name'] }
    end

    context 'asc' do
      let(:sort_param) { '-first_name' }

      it { is_expected.to eq(%w(Philip Stephen)) }
    end

    context 'desc' do
      let(:sort_param) { 'first_name' }

      it { is_expected.to eq(%w(Stephen Philip)) }
    end

    context 'when given a custom sort function' do
      let(:sort_param) { '-first_name' }

      before do
        controller.class_eval do
          jsonapi do
            sort do |scope, att, dir|
              scope.special_sort(att, dir)
            end
          end
        end
      end

      it 'should use the custom sort function' do
        scope = double(is_a?: true).as_null_object
        expect(Author).to receive(:all) { scope }
        expect(scope).to receive(:special_sort)
          .with(:first_name, :asc).and_return(scope)
        get :index, params: { sort: sort_param }
      end
    end
  end

  context 'when paginating' do
    let!(:author1) { Author.create!(first_name: 'Philip', last_name: 'Roth',state_attributes: { id: newyork.id }) }
    let!(:author2) { Author.create!(first_name: 'Philip', last_name: 'Roth',state_attributes: { id: newyork.id }) }
    let!(:author3) { Author.create!(first_name: 'Philip', last_name: 'Roth',state_attributes: { id: newyork.id }) }
    let!(:author4) { Author.create!(first_name: 'Philip', last_name: 'Roth',state_attributes: { id: newyork.id }) }

    it 'should raise error when size > 1000' do
      expect {
        get :index, params: { page: { number: 2, size: 1001 } }
      }.to raise_error(JSONAPICompliable::UnsupportedPageSize)
    end

    it 'should limit by size, offset by number' do
      get :index, params: { page: { number: 2, size: 2 } }
      expect(json_ids(true)).to eq([author3.id, author4.id])
    end

    context 'and a custom pagination function is given' do
      before do
        controller.class_eval do
          jsonapi do
            paginate do |scope, page, per_page|
              scope.special_pagination(page, per_page)
            end
          end
        end
      end

      it 'should use the custom pagination function' do
        scope = double(is_a?: true).as_null_object
        expect(Author).to receive(:all) { scope }
        expect(scope).to receive(:special_pagination)
          .with(3, 2).and_return(scope)
        get :index, params: { page: { number: 3, size: 2 } }
      end
    end
  end

  context 'when passed object(s), not scope' do
    it 'does not eager load' do
      authors = double
      allow(Author).to receive(:all).and_return(authors)
      expect(authors).to_not receive(:includes)

      get :index, params: { include: 'books.genre,foo' }
    end
  end

  context 'when nested includes' do
    it 'only allows valid nestings' do
      scope = double.as_null_object
      allow(scope).to receive(:is_a?).with(ActiveRecord::Relation) { true }
      allow(Author).to receive(:all).and_return(scope)
      expect(scope).to receive(:includes)
        .with(books: { genre: {} }, state: {})

      get :index, params: { include: 'books.genre,state' }
    end
  end

  context 'when requesting custom fieldset' do
    let!(:author) { Author.create!(first_name: 'Philip', last_name: 'Roth',state_attributes: { id: newyork.id }) }

    let(:custom_serializer) do
      Class.new(ApplicationSerializer) do
        attributes :created_at,
          :updated_at,
          :first_name,
          :last_name,
          :state_id
        attribute :hostname, if: :allow_hostname?
        extra_attributes :foo, :bar, :baz

        def allow_hostname?
          true
        end

        def foo
          88
        end

        def hostname
          "somehost"
        end

        def bar
          99
        end

        def baz
          101
        end
      end
    end

    before do
      controller.class_eval do
        jsonapi do
          extra_field({ authors: :foo }, &:include_foo!)
        end

        def index
          render_ams(Author.all, each_serializer: serializer)
        end
      end

      controller.serializer = custom_serializer
    end

    it 'should limit to only the requested fields' do
      get :index, params: { fields: { authors: 'first_name,updated_at' } }
      expect(json_items(0).keys).to match_array(%w(id jsonapi_type first-name updated-at))
    end

    it 'should still disallow fields guarded by :if' do
      allow_any_instance_of(custom_serializer)
        .to receive(:allow_hostname?) { false }
      get :index, params: { fields: { authors: 'hostname,updated_at' } }
      expect(json_items(0).keys).to match_array(%w(id jsonapi_type updated-at))
    end

    context 'when requesting extra fields' do
      let(:scope) do
        scope = Author.all
        scope.instance_eval do
          def include_foo!
            self
          end
        end
        scope
      end

      before do
        scope
        allow(Author).to receive(:all) { scope }
      end

      it 'should include the extra fields in the response' do
        get :index, params: { extra_fields: { authors: 'foo,bar' } }
        expect(json_items(0).slice('foo', 'bar'))
          .to eq('foo' => 88, 'bar' => 99)
      end

      it 'should not limit base fields' do
        get :index, params: { extra_fields: { authors: 'foo,bar' } }
        expect(json_items(0)['first-name']).to eq(author.first_name)
      end

      it 'should alter the scope correctly' do
        expect(scope).to receive(:include_foo!).and_return(scope)
        get :index, params: { extra_fields: { authors: 'foo' } }
        expect(json_items(0)['foo']).to eq(88)
      end

      it 'should not include extra fields when not requested' do
        get :index
        expect(json_items(0).keys).to_not include('foo')
        expect(json_items(0).keys).to_not include('bar')
      end

      context 'when extra field is requestd but still not allowed' do
        before do
          allow_any_instance_of(custom_serializer)
            .to receive(:allow_foo?) { false }
        end

        it 'should not include the extra field in the response' do
          get :index, params: { extra_fields: { authors: 'foo,bar' } }
          expect(json_items(0).slice('foo', 'bar')).to eq('bar' => 99)
        end
      end
    end
  end

  context 'when filtering' do
    let!(:author1) { Author.create!(first_name: 'Stephen', last_name: 'King',state_attributes: { id: newyork.id }) }
    let!(:author2) { Author.create!(first_name: 'Agartha', last_name: 'Christie',state_attributes: { id: newyork.id }) }
    let!(:author3) { Author.create!(first_name: 'Willaim', last_name: 'Shakesphere',state_attributes: { id: newyork.id }) }
    let!(:author4) { Author.create!(first_name: 'AHarold', last_name: 'Robbins',state_attributes: { id: newyork.id }) }

    context 'and the filter is not allowed' do
      it 'should raise an error' do
        expect {
          get :index, params: { filter: { foo: 'bar' } }
        }.to raise_error(JSONAPICompliable::BadFilter)
      end
    end

    context 'and there is a default filter' do
      before do
        controller.class_eval do
          jsonapi do
            default_filter :first_name do |scope|
              scope.where(first_name: 'Willaim')
            end
          end
        end
      end

      it 'applies by default' do
        get :index
        expect(json_ids(true)).to eq([author3.id])
      end

      it 'is overridable if an allowed filter' do
        controller.class_eval do
          jsonapi do
            allow_filter :last_name

            default_filter :last_name do |scope|
              scope.where(last_name: 'King')
            end
          end
        end

        get :index, params: { filter: { last_name: author4.last_name } }
        expect(json_ids(true)).to eq([author4.id])
      end

      it 'is overridable if an allowed filter has a corresponding alias' do
        controller.class_eval do
          jsonapi do
            allow_filter :title, aliases: [:first_name] do |scope, value|
              scope.where(first_name: value)
            end

            default_filter :first_name do |scope|
              scope.where(first_name: 'John')
            end
          end
        end

        get :index, params: { filter: { title: author1.first_name } }
        expect(json_ids(true)).to eq([author1.id])
      end
    end

    context 'and the filter is allowed' do
      context 'and is customized with a block' do
        it 'should filter correctly via block' do
          get :index, params: { filter: { first_name_prefix: 'A' } }
          expect(json_ids(true)).to eq([author2.id, author4.id])
        end
      end

      context 'with alternate param name' do
        it 'should filter correctly' do
          get :index, params: { filter: { title: author2.first_name } }
          expect(json_ids(true)).to eq([author2.id])
        end
      end

      context 'and is not customized with a block' do
        it 'should provide default ActiveRecord filter' do
          get :index, params: { filter: { first_name: author2.first_name } }
          expect(json_ids(true)).to eq([author2.id])
        end
      end

      context 'and is comma-delimited' do
        it 'should automatically be parsed into a ruby array' do
          get :index, params: { filter: { first_name: [author2.first_name, author3.first_name].join(',') } }
          expect(json_ids(true)).to eq([author2.id, author3.id])
        end
      end

      context 'but guard clause is falsey' do
        before do
          expect(controller).to receive(:can_filter_first_name?) { false }
        end

        it 'should raise error' do
          expect {
            get :index, params: { filter: { first_name: author2.first_name } }
          }.to raise_error(JSONAPICompliable::BadFilter)
        end
      end
    end
  end
end
