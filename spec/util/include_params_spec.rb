require "spec_helper"

RSpec.describe Graphiti::Util::IncludeParams do
  describe ".scrub" do
    let(:requested) do
      {foo: {bar: {baz: {}}, blah: {}, blah2: {}}}
    end

    let(:allowed) do
      {foo: {bar: {}, blah: {}}}
    end

    subject { described_class.scrub(requested, allowed) }

    it { is_expected.to eq(foo: {bar: {}, blah: {}}) }
  end
end
