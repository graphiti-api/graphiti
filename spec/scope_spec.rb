require 'spec_helper'

RSpec.describe JsonapiCompliable::Scope do
  let(:object)   { double.as_null_object }
  let(:resource) { double(type: :authors, default_page_size: 1).as_null_object }
  let(:query)    { double(to_hash: { authors: JsonapiCompliable::Query.default_hash }) }
  let(:instance) { described_class.new(object, resource, query) }

  describe '#resolve' do
    before do
      allow(query).to receive(:zero_results?) { false }
    end

    it 'returns the object' do
      expect(instance.resolve).to eq(instance.instance_variable_get(:@object))
    end

    context 'when 0 results requested' do
      before do
        allow(query).to receive(:zero_results?) { true }
      end

      it 'returns empty array' do
        expect(instance.resolve).to eq([])
      end
    end
  end
end
