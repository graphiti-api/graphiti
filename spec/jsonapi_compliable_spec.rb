require 'spec_helper'

RSpec.describe JsonapiCompliable, type: :controller do
  controller(ApplicationController) do
    jsonapi do
      type :authors
    end

    def index
      scope = Author.all
      render_jsonapi(scope)
    end
  end

  describe '.jsonapi' do
    let(:subclass1) do
      Class.new(controller.class) do
        jsonapi do
          type :subclass_1
          allow_filter :id
          allow_filter :foo
        end
      end
    end

    let(:subclass2) do
      Class.new(subclass1) do
        jsonapi do
          type :subclass_2
          allow_filter :foo do |scope, value|
            'foo'
          end
        end
      end
    end

    it 'assigns a subclass of Resource by default' do
      expect(controller.class._jsonapi_compliable.ancestors)
        .to include(JsonapiCompliable::Resource)
      expect(controller.class._jsonapi_compliable.object_id)
        .to_not eq(JsonapiCompliable::Resource.object_id)
    end

    context 'when subclassing and customizing' do
      def config(obj)
        obj._jsonapi_compliable.config
      end

      it 'preserves values from superclass' do
        expect(config(subclass2)[:filters][:id]).to_not be_nil
      end

      it 'does not alter superclass when overriding' do
        expect(config(subclass1)).to_not eq(config(subclass2))
        expect(config(subclass1)[:filters][:id].object_id)
          .to_not eq(config(subclass2)[:filters][:id].object_id)
        expect(config(subclass1)[:filters][:foo][:filter]).to be_nil
        expect(config(subclass2)[:filters][:foo][:filter]).to_not be_nil
      end

      it 'overrides type for subclass' do
        expect(config(subclass2)[:type]).to eq(:subclass_2)
        expect(config(subclass1)[:type]).to eq(:subclass_1)
      end
    end
  end

  describe '#render_jsonapi' do
    it 'is able to override options' do
      author = Author.create!(first_name: 'Stephen', last_name: 'King')
      author.books.create(title: "The Shining", genre: Genre.new(name: 'horror'))

      controller.class_eval do
        def index
          scope = Author.all
          render_jsonapi(scope, include: { books: :genre })
        end
      end

      get :index
      expect(json_included_types).to match_array(%w(books genres))
    end

    context 'when passing scope: false' do
      before do
        controller.class_eval do
          def index
            people = Author.all
            render_jsonapi(people.to_a, scope: false)
          end
        end
      end

      it 'does not appy jsonapi_scope' do
        author = double
        allow(Author).to receive(:all).and_return([author])
        expect(Author).to_not receive(:find_by_sql)
        expect(author).to_not receive(:includes)
        expect(controller).to_not receive(:jsonapi_scope)

        get :index, params: { include: 'books.genre,foo' }
      end
    end
  end
end
