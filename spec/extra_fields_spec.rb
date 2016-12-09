require 'spec_helper'

RSpec.describe 'extra_fields', type: :controller do
  class SerializableTestExtraFields < JSONAPI::Serializable::Resource
    type 'authors'
    attributes :first_name, :last_name
    extra_attribute :net_worth, if: proc { @context.allow_net_worth? } do
      100_000_000
    end
  end

  controller(ApplicationController) do
    jsonapi do
      extra_field(authors: :net_worth) do |scope|
        scope.include_foo!
      end
    end

    def allow_net_worth?
      true
    end

    def index
      render_jsonapi(Author.all, class: SerializableTestExtraFields)
    end
  end

  let(:scope) do
    scope = Author.all
    scope.instance_eval do
      def include_foo!
        self
      end
    end
    scope
  end

  let!(:author) { Author.create!(first_name: 'Stephen', last_name: 'King') }

  before do
    scope
    allow(Author).to receive(:all) { scope }
  end

  it 'does not include extra fields when not requested' do
    get :index
    expect(json_items(0).keys).to match_array(%w(id jsonapi_type first_name last_name))
  end

  it 'includes the extra fields in the response when requested' do
    get :index, params: { extra_fields: { authors: 'net_worth' } }
    expect(json_items(0).keys).to match_array(%w(id jsonapi_type first_name last_name net_worth))
  end

  it 'alters the scope based on the supplied block' do
    expect(scope).to receive(:include_foo!).and_return(scope)
    get :index, params: { extra_fields: { authors: 'net_worth' } }
  end

  context 'when extra field is requested but guarded' do
    before do
      allow(controller).to receive(:allow_net_worth?) { false }
    end

    it 'does not include the extra field in the response' do
      get :index, params: { extra_fields: { authors: 'net_worth' } }
      expect(json_items(0).keys).to match_array(%w(id jsonapi_type first_name last_name))
    end
  end
end
