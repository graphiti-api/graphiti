require 'spec_helper'

RSpec.describe JsonapiCompliable do
  let(:klass) do
    Class.new do
      attr_accessor :params
      include JsonapiCompliable::Base

      def jsonapi_resource
        PORO::EmployeeResource.new
      end

      def params
        @params || {}
      end
    end
  end

  let(:instance) { klass.new }

  describe '#wrap_context' do
    before do
      allow(instance).to receive(:action_name) { 'index' }
    end

    it 'wraps in the resource context' do
      instance.wrap_context do
        expect(instance.jsonapi_resource.context).to eq(instance)
        expect(instance.jsonapi_resource.context_namespace).to eq(:index)
      end
    end
  end

  describe '#jsonapi_context' do
    let(:ctx) { double('context') }

    before do
      allow(instance).to receive(:jsonapi_context) { ctx }
      allow(instance).to receive(:action_name) { 'index' }
    end

    it 'sets the context to the given override' do
      instance.wrap_context do
        expect(instance.jsonapi_resource.context).to eq(ctx)
      end
    end
  end

  describe '#proxy' do
    it 'returns a proxy with access to records, stats, and query' do
      scope = double(resolve: 'resolved', resolve_stats: 'stats')
      expect(instance).to receive(:jsonapi_scope).with('foo', {}) { scope }
      proxy = instance.proxy('foo')
      expect(proxy).to be_a(JsonapiCompliable::ResourceProxy)
      expect(proxy.query).to be_a(JsonapiCompliable::Query)
      expect(proxy.to_a).to eq('resolved')
      expect(proxy.stats).to eq('stats')
    end
  end
end
