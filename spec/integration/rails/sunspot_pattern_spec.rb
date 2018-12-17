if ENV['APPRAISAL_INITIALIZED']
  # This tests the 'Sunspot Pattern':
  # Querying using ElasticSearch, Solr, etc, but returning ActiveRecord objects
  #
  # In this scenario, we need to associate the resulting models using the
  # AR adapter, even though the Resource adapter is not ActiveRecord.
  # Otherwise, we will try to associate these as if they are POROs - which will
  # have adverse side-effects because of AR magic.
  #
  # This scenario is likely specific to ActiveRecord.
  RSpec.describe 'a non-ActiveRecord adapter that returns ActiveRecord models', type: :controller do
    include GraphitiSpecHelpers

    controller(ApplicationController) do
      def index
        authors = Legacy::AuthorSearchResource.all(params)
        render jsonapi: authors
      end
    end

    let!(:author) do
      Legacy::Author.create!(first_name: 'Stephen', state: state)
    end
    let!(:book) { Legacy::Book.create!(title: 'Foo', author: author) }
    let!(:state) { Legacy::State.create!(name: 'Maine') }

    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with('PATH_INFO') { path }
    end

    let(:path) { '/legacy/author_searches' }

    it 'works' do
      do_index({ include: 'special_books' })
      expect(d[0].sideload(:special_books).map(&:id)).to eq([book.id])
    end

    context 'belongs_to' do
      it 'works' do
        do_index({ include: 'special_state' })
        expect(d[0].sideload(:special_state).id).to eq(state.id)
      end
    end
  end
end
