require 'spec_helper'

RSpec.describe 'integrated resources and adapters', type: :controller do
  module Integration
    class AuthorResource < JsonapiCompliable::Resource
      type :authors
      use_adapter JsonapiCompliable::Adapters::ActiveRecord

      allow_filter :first_name
    end
  end

  controller(ApplicationController) do
    jsonapi resource: Integration::AuthorResource

    def index
      render_jsonapi(Author.all)
    end
  end

  let!(:author1) { Author.create!(first_name: 'Stephen') }
  let!(:author2) { Author.create!(first_name: 'George') }

  it 'allows basic sorting' do
    get :index, params: { sort: '-id' }
    expect(json_ids(true)).to eq([author2.id, author1.id])
  end

  it 'allows basic pagination' do
    get :index, params: { page: { number: 2, size: 1 } }
    expect(json_ids(true)).to eq([author2.id])
  end

  it 'allows whitelisted filters (and other configs)' do
    get :index, params: { filter: { first_name: 'George' } }
    expect(json_ids(true)).to eq([author2.id])
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
