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

  describe '.map' do
    it 'auto-adds canonical name' do
      expect(described_class.map.values).to all(have_key(:canonical_name))
    end

    it 'auto-adds array_of_* equivalents' do
      types = described_class.map.keys
      expect(types).to include(:array_of_integers)
      expect(types).to include(:array_of_strings)
      expect(types).to include(:array_of_datetimes)
      expect(types).to include(:array_of_dates)
      expect(types).to include(:array_of_floats)
      expect(types).to include(:array_of_decimals)
      expect(types).to include(:array_of_booleans)
      expect(types).to include(:array_of_hashes)
      expect(types).to include(:array_of_arrays)
    end
  end

  describe '.name_for' do
    it 'returns canonical name' do
      expect(described_class.name_for(:array_of_integers)).to eq(:integer)
    end

    context 'when passed a string' do
      it 'works' do
        expect(described_class.name_for('array_of_integers'))
          .to eq(:integer)
      end
    end
  end
end
