require 'spec_helper'

RSpec.describe 'fields', type: :controller do
  controller(ApplicationController) do
    jsonapi {}

    class TestFieldsSerializer < ActiveModel::Serializer
      attributes :first_name, :last_name, :uuid
      attribute :salary, if: :admin?

      def uuid
        SecureRandom.uuid
      end

      def admin?
        scope == 'admin'
      end

      def salary
        50_000
      end
    end

    def index
      render_ams(Author.all, each_serializer: TestFieldsSerializer)
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
