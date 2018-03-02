require 'spec_helper'

RSpec.describe JsonapiCompliable::Scope do
  let(:object)     { double.as_null_object }
  let(:query_hash) { JsonapiCompliable::Query.default_hash }
  let(:query)      { double(to_hash: { authors: query_hash }) }
  let(:instance)   { described_class.new(object, resource, query) }

  let(:resource) do
    dbl = double type: :authors,
      default_page_size: 1,
      pagination: nil
    dbl.as_null_object
  end

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
      let(:sideload) { double(name: :books) }
      let(:results)  { double }

      before do
        query_hash[:include] = { books: {} }
        objekt = instance.instance_variable_get(:@object)
        allow(resource).to receive(:resolve).with(objekt) { results }
      end

      context 'when the requested sideload exists on the resource' do
        before do
          allow(resource).to receive(:sideload).with(:books) { sideload }
        end

        it 'resolves the sideload' do
          expect(sideload).to receive(:resolve).with(results, query, sideload.name)
          instance.resolve
        end

        context 'and it is nested within the same namespace' do
          xit 'resolves with the correct namespace' do
          end
        end

        context 'but no parents were found' do
          let(:results) { [] }

          it 'does not resolve the sideload' do
            expect(sideload).to_not receive(:resolve)
            instance.resolve
          end
        end
      end

      context 'when the requested sideload does not exist' do
        before do
          allow(resource).to receive(:sideload).with(:books) { nil }
        end

        it 'raises a helpful error' do
          expect do
            instance.resolve
          end.to raise_error(JsonapiCompliable::Errors::InvalidInclude, 'The requested included relationship "books" is not supported on resource "authors"')
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
