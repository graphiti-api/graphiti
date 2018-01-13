require 'spec_helper'

RSpec.describe 'fields' do
  include_context 'scoping'

  class SerializableTestFields < JSONAPI::Serializable::Resource
    type 'authors'

    attribute :first_name
    attribute :last_name
    attribute :uuid do
      SecureRandom.uuid
    end
    attribute :salary, if: proc { !@context || @context.current_user == 'admin' } do
      50_000
    end

    def admin?
      scope == 'admin'
    end
  end

  let!(:author) { Author.create!(first_name: 'Stephen', last_name: 'King') }

  def json
    render(scope.resolve, class: { Author: SerializableTestFields })
  end

  it 'does not limit without fields param' do
    expect(json['data'][0]['attributes'].keys).to eq(%w(first_name last_name uuid salary))
  end

  it 'limits to only the requested fields' do
    params[:fields] = { authors: 'first_name,last_name' }
    expect(json['data'][0]['attributes'].keys).to eq(%w(first_name last_name))
  end

  it 'disallows fields guarded by :if, even if specified' do
    params[:fields] = { authors: 'first_name,salary' }
    ctx = double(current_user: 'non-admin').as_null_object
    resource.with_context ctx do
      expect(json['data'][0]['attributes'].keys).to_not include('salary')
    end
    ctx = double(current_user: 'admin')
    resource.with_context ctx do
      expect(json['data'][0]['attributes'].keys).to include('salary')
    end
  end
end
