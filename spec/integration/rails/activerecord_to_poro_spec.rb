if ENV['APPRAISAL_INITIALIZED']
  RSpec.describe 'associating an ActiveRecord to a PORO', type: :controller do
    include GraphitiSpecHelpers

    module ARToPORO
      class AuthorResource < Legacy::ApplicationResource
        self.model = Legacy::Author
        has_many :books
        belongs_to :state
      end

      class BookResource < PORO::ApplicationResource
        self.model = PORO::Book
        attribute :author_id, :integer, only: [:filterable]
        attribute :title, :string
      end

      class StateResource < PORO::ApplicationResource
        self.model = PORO::State
        attribute :name, :string
      end

      Graphiti.setup!
    end

    controller(ApplicationController) do
      def index
        authors = ARToPORO::AuthorResource.all(params)
        render jsonapi: authors
      end
    end

    let!(:author) { Legacy::Author.create!(state_id: state.id) }
    let!(:book) { PORO::Book.create(title: 'Foo', author_id: author.id) }
    let!(:state) { PORO::State.create(name: 'Alabama') }

    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with('PATH_INFO') { path }
    end

    let(:path) { '/ar_to_poro/authors' }

    context 'when has_many' do
      it 'works' do
        do_index({ include: 'books' })
        sl = d[0].sideload(:books)
        expect(sl.map(&:id)).to eq([book.id])
        expect(sl[0].jsonapi_type).to eq('books')
      end
    end

    context 'when belongs_to' do
      it 'works' do
        do_index({ include: 'state' })
        sl = d[0].sideload(:state)
        expect(sl.id).to eq(state.id)
        expect(sl.jsonapi_type).to eq('states')
      end
    end
  end
end
