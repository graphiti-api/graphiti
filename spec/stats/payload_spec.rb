require 'spec_helper'

RSpec.describe JsonapiCompliable::Stats::Payload do
  let(:controller) { double.as_null_object }
  let(:scope) { double.as_null_object }
  let(:instance) { described_class.new(controller, scope) }
  let(:params) { { stats: { attr1: 'count,average', attr2: 'maximum' } } }
  let(:dsl) { double }

  before do
    allow(controller).to receive(:params) { params }
    allow(controller).to receive(:_jsonapi_compliable) { dsl }
  end

  describe '#generate' do
    subject { instance.generate }

    def stub_stat(attr, calc, result)
      allow(dsl).to receive(:stat).with(attr, calc) { ->(_,_) { result } }
    end

    before do
      stub_stat(:attr1, :count, 2)
      stub_stat(:attr1, :average, 1)
      stub_stat(:attr2, :maximum, 3)
    end

    it 'generates the correct payload for each requested stat' do
      expect(subject).to eq({
        attr1: { count: 2, average: 1 },
        attr2: { maximum: 3 }
      })
    end
  end

  describe '.new' do
    it 'derives scope from controller' do
      instance = described_class.new(controller, 'a')
      expect(instance.instance_variable_get(:@scope))
        .to eq(controller._jsonapi_scope)
    end

    context 'when scope not on controller' do
      before do
        allow(controller).to receive(:_jsonapi_scope) { nil }
      end

      it 'uses that scope' do
        instance = described_class.new(controller, 'a')
        expect(instance.instance_variable_get(:@scope))
          .to eq('a')
      end
    end
  end
end
