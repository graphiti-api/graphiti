require 'spec_helper'

RSpec.describe JsonapiCompliable, type: :controller do
  controller(ApplicationController) do
    jsonapi { }

    def index
      scope = Author.all
      render_ams(scope)
    end
  end

  describe '.jsonapi' do
    let(:subclass1) do
      Class.new(controller.class) do
        jsonapi do
          allow_filter :id
          allow_filter :foo
        end
      end
    end

    let(:subclass2) do
      Class.new(subclass1) do
        jsonapi do
          allow_filter :foo do |scope, value|
            'foo'
          end
        end
      end
    end

    context 'when subclassing and customizing' do
      it 'preserves values from superclass' do
        expect(subclass2._jsonapi_compliable.filters[:id]).to_not be_nil
      end

      it 'does not alter superclass when overriding' do
        expect(subclass1._jsonapi_compliable)
          .to_not eq(subclass2._jsonapi_compliable)
        expect(subclass1._jsonapi_compliable.filters[:id].object_id)
          .to_not eq(subclass2._jsonapi_compliable.filters[:id].object_id)
        expect(subclass1._jsonapi_compliable.filters[:foo][:filter]).to be_nil
        expect(subclass2._jsonapi_compliable.filters[:foo][:filter]).to_not be_nil
      end
    end
  end

  describe '#render_ams' do
    it 'is able to override options' do
      author = Author.create!(first_name: 'Stephen', last_name: 'King')
      author.books.create(title: "The Shining", genre: Genre.new(name: 'horror'))

      controller.class_eval do
        def index
          scope = Author.all
          render_ams(scope, include: { books: :genre })
        end
      end

      get :index
      expect(json_included_types).to match_array(%w(books genres))
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

      let!(:author) { Author.create!(first_name: 'Stephen', last_name: 'King') }
      let!(:book) { author.books.create(title: "The Shining") }

      it 'does not re-apply scopes' do
        expect(controller).to receive(:jsonapi_scope)
          .once
          .and_call_original
        get :index
        expect(json_items(0)['first_name']).to eq('Stephen')
      end
    end

    it 'resets scope flag after action' do
      controller.instance_variable_set(:@_jsonapi_scope, 'a')
      expect {
        get :index
      }.to change { controller.instance_variable_get(:@_jsonapi_scope) }
        .from('a').to(nil)
    end

    context 'when passing scope: false' do
      before do
        controller.class_eval do
          def index
            people = Author.all
            render_ams(people, scope: false)
          end
        end
      end

      it 'does not appy jsonapi_scope' do
        author = double
        allow(Author).to receive(:all).and_return([author])
        expect(author).to_not receive(:includes)
        expect(controller).to_not receive(:jsonapi_scope)

        get :index, params: { include: 'books.genre,foo' }
      end
    end
  end
end
