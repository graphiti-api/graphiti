require 'spec_helper'

RSpec.describe JsonapiCompliable::Scope do
  let(:object)     { double.as_null_object }
  let(:resource)   { double(type: :authors, default_page_size: 1).as_null_object }
  let(:query_hash) { JsonapiCompliable::Query.default_hash }
  let(:query)      { double(to_hash: { authors: query_hash }) }
  let(:instance)   { described_class.new(object, resource, query) }

  describe '#resolve' do
    before do
      allow(query).to receive(:zero_results?) { false }
    end

    it 'resolves via resource' do
      # object gets modified in the Scope's constructor
      objekt = instance.instance_variable_get(:@object)
      expect(resource).to receive(:resolve).with(objekt).and_return(objekt)
      instance.resolve
    end

    it 'returns the object' do
      expect(instance.resolve).to eq(instance.instance_variable_get(:@object))
    end

    context 'when sideloading' do
      let(:sideload) { double }
      let(:results)  { double }

      before do
        query_hash[:include] = { books: {} }
        objekt = instance.instance_variable_get(:@object)
        allow(resource).to receive(:resolve).with(objekt) { results }
      end

      context 'when the requested sideload is allowed' do
        before do
          allow(resource).to receive(:allowed_sideloads) { { books: {} } }
          allow(resource).to receive(:sideload).with(:books) { sideload }
        end

        it 'resolves the sideload' do
          expect(sideload).to receive(:resolve).with(results, query)
          instance.resolve
        end
      end

      context 'when the requested sideload is not allowed' do
        before do
          allow(resource).to receive(:allowed_sideloads) { {} }
        end

        it 'does not resolve the sideload' do
          expect(resource).to_not receive(:sideload)
          expect(sideload).to_not receive(:resolve)
          instance.resolve
        end
      end
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
