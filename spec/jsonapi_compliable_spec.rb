require 'spec_helper'

RSpec.describe JsonapiCompliable do
  let(:klass) do
    Class.new do
      attr_accessor :params
      include JsonapiCompliable::Base

      jsonapi resource: PORO::EmployeeResource

      def params
        @params || {}
      end
    end
  end

  let(:instance) { klass.new }

  describe '.jsonapi' do
    let(:subclass1) do
      Class.new(klass)
    end

    let(:subclass2) do
      Class.new(subclass1) do
        jsonapi resource: PORO::PositionResource
      end
    end

    context 'when subclassing and customizing' do
      it 'preserves values from superclass' do
        expect(subclass1._jsonapi_compliable.type).to eq(:employees)
      end

      it 'can override in subclass' do
        expect(subclass1._jsonapi_compliable.type).to eq(:employees)
        expect(subclass2._jsonapi_compliable.type).to eq(:positions)
      end
    end
  end

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

  describe '#records' do
    it 'scopes, returning stats and models' do
      scope = double(resolve: 'resolved', resolve_stats: 'stats')
      expect(instance).to receive(:jsonapi_scope).with('foo') { scope }
      expect(instance.resolve('foo')).to eq(['resolved', 'stats'])
    end
  end

  describe '#render_jsonapi' do
    before do
      allow(instance).to receive(:force_includes?) { false }
    end

    it 'is able to override options' do
      json = instance.render_jsonapi([], {
        apply_scoping: false, meta: { foo: 'bar' }
      })
      hash = JSON.parse(json)
      expect(hash['meta']).to eq('foo' => 'bar')
    end

    context 'when passing apply_scoping: false' do
      it 'does not appy jsonapi_scope' do
        expect(PORO::DB).to_not receive(:all)
        instance.render_jsonapi([], apply_scoping: false)
      end
    end

    context 'when passing manual :include' do
      it 'respects the :include option' do
        expect(JsonapiCompliable::Renderer).to receive(:new)
          .with(anything, hash_including(include: { foo: {}}))
          .and_call_original
        instance.render_jsonapi([], {
          include: { foo: {} }, apply_scoping: false
        })
      end
    end
  end
end
