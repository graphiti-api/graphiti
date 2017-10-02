require 'spec_helper'

RSpec.describe 'extra_fields' do
  include_context 'scoping'

  class SerializableTestExtraFields < JSONAPI::Serializable::Resource
    type 'authors'
    attributes :first_name, :last_name
    extra_attribute :net_worth, if: proc { !@context || @context.allow_net_worth? } do
      100_000_000
    end
  end

  before do
    resource_class.class_eval do
      extra_field :net_worth do |scope|
        scope.include_foo!
      end
    end
  end

  let!(:scope_object) do
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
    allow(Author).to receive(:all) { scope_object }
  end

  let(:json) do
    render(scope.resolve, class: SerializableTestExtraFields)
  end

  it 'does not include extra fields when not requested' do
    expect(json['data'][0]['attributes'].keys).to match_array(%w(first_name last_name))
  end

  it 'includes the extra fields in the response when requested' do
    params[:extra_fields] = { authors: 'net_worth' }
    expect(json['data'][0]['attributes'].keys).to match_array(%w(first_name last_name net_worth))
  end

  it 'alters the scope based on the supplied block' do
    params[:extra_fields] = { authors: 'net_worth' }
    expect(json['data'][0]['attributes'].keys).to match_array(%w(first_name last_name net_worth))
  end

  context 'when extra field is requested but guarded' do
    before do
      params[:extra_fields] = { authors: 'net_worth' }
    end

    it 'does not include the extra field in the response' do
      ctx = double(allow_net_worth?: false).as_null_object
      resource.with_context ctx do
        expect(json['data'][0]['attributes'].keys).to match_array(%w(first_name last_name))
      end
    end
  end
end
