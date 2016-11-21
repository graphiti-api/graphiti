require 'spec_helper'

RSpec.describe JsonapiCompliable::Util::Scoping do
  describe '.apply?' do
    let(:force)      { true }
    let(:controller) { double.as_null_object }
    let(:object)     { Author.all }

    subject { described_class.apply?(controller, object, force) }

    before do
      allow(controller).to receive(:_jsonapi_scope) { nil }
    end

    it { is_expected.to be(true) }

    context 'when forcing no scope' do
      let(:force) { false }

      it { is_expected.to be(false) }
    end

    context 'when controller has already scoped' do
      before do
        allow(controller).to receive(:_jsonapi_scope) { Author.where(name: 'asdf') }
      end

      it { is_expected.to be(false) }
    end

    context 'when a PORO' do
      let(:object) { Class.new }

      it { is_expected.to be(true) }
    end

    context 'when object is an ActiveRecord instance' do
      let(:object) { Author.new }

      it { is_expected.to be(false) }
    end

    context 'when object is an array of ActiveRecord instances' do
      let(:object) { [Author.new] }

      it { is_expected.to be(false) }
    end
  end
end
