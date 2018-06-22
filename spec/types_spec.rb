require 'spec_helper'

RSpec.describe JsonapiCompliable::Types do
  after do
    described_class.instance_variable_set(:@map, nil)
  end

  describe '.[]=' do
    context 'when key is string' do
      before do
        described_class['string'] = 'foo'
      end

      it 'works' do
        expect(described_class[:string]).to be_present
      end
    end

    context 'when value is a hash' do
      before do
        described_class[:string] = { foo: 'bar' }
      end

      it 'works' do
        expect(described_class[:string]).to eq(foo: 'bar')
      end
    end

    context 'when value is a type' do
      before do
        described_class[:string] = 'foo'
      end

      it 'assigns the type to all operations' do
        expect(described_class[:string]).to eq({
          read: 'foo',
          params: 'foo',
          test: 'foo'
        })
      end
    end
  end

  describe '[]' do
    it 'works with symbols' do
      expect(described_class[:string]).to be_present
    end

    it 'works with strings' do
      expect(described_class['string']).to be_present
    end
  end
end
