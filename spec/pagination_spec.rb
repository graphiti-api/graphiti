require 'spec_helper'

RSpec.describe 'pagination', type: :controller do
  controller(ApplicationController) do
    jsonapi {}

    def index
      render_ams(Author.all)
    end
  end

  let!(:author1) { Author.create! }
  let!(:author2) { Author.create! }
  let!(:author3) { Author.create! }
  let!(:author4) { Author.create! }

  it 'applies default pagination' do
    allow(controller).to receive(:default_page_size) { 2 }
    get :index
    expect(json_ids.length).to eq(2)
  end

  it 'raises error when size > 1000' do
    expect {
      get :index, params: { page: { number: 1, size: 1001 } }
    }.to raise_error(JsonapiCompliable::Errors::UnsupportedPageSize)
  end

  it 'limits by size, offsets by number' do
    get :index, params: { page: { number: 2, size: 2 } }
    expect(json_ids(true)).to eq([author3.id, author4.id])
  end

  # for metadata
  context 'with page size 0' do
    it 'should not respond with records, but still respond' do
      get :index, params: { page: { size: 0 } }
      expect(json_ids).to eq([])
    end
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

    it 'uses the custom pagination function' do
      scope = double(is_a?: true).as_null_object
      expect(Author).to receive(:all) { scope }
      expect(scope).to receive(:special_pagination)
        .with(3, 2).and_return(scope)
      get :index, params: { page: { number: 3, size: 2 } }
    end
  end
end
