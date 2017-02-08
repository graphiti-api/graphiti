require 'spec_helper'

RSpec.describe JsonapiCompliable::Util::Hash do
  describe '.keys' do
    it 'recursively collects keys' do
      hash = { foo: { bar: {} }, baz: {} }
      expect(described_class.keys(hash)).to eq([:foo, :bar, :baz])
    end
  end
end
