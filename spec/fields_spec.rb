require 'spec_helper'

RSpec.describe 'fields', type: :controller do
  controller(ApplicationController) do
    jsonapi {}

    class SerializableTestFields < JSONAPI::Serializable::Resource
      type 'authors'

      attribute :first_name
      attribute :last_name
      attribute :uuid do
        SecureRandom.uuid
      end
      attribute :salary, if: proc { @context.current_user == 'admin' } do
        50_000
      end

      def admin?
        scope == 'admin'
      end
    end

    def index
      render_jsonapi(Author.all, class: SerializableTestFields)
    end

    def current_user
      'non-admin'
    end
  end

  let!(:author) { Author.create!(first_name: 'Stephen', last_name: 'King') }

  it 'limits to only the requested fields' do
    get :index
    expect(json_items(0).keys).to match_array(%w(id jsonapi_type first_name last_name uuid))
    get :index, params: { fields: { authors: 'first_name,last_name' } }
    expect(json_items(0).keys).to match_array(%w(id jsonapi_type first_name last_name))
  end

  it 'disallows fields guarded by :if, even if specified' do
    allow(controller).to receive(:current_user) { 'admin' }
    get :index, params: { fields: { authors: 'first_name,salary' } }
    expect(json_items(0).keys).to match_array(%w(id jsonapi_type first_name salary))
    allow(controller).to receive(:current_user) { 'non-admin' }
    get :index, params: { fields: { authors: 'first_name,salary' } }
    expect(json_items(0).keys).to match_array(%w(id jsonapi_type first_name))
  end
end
