require "spec_helper"

RSpec.describe Graphiti::Stats::Payload do
  let(:dsl) { double }
  let(:query) { double(stats: {attr1: [:count, :average], attr2: [:maximum]}) }
  let(:scope) { double.as_null_object }
  let(:data) { double.as_null_object }
  let(:instance) { described_class.new(dsl, query, scope, data) }

  describe "#generate" do
    subject { instance.generate }

    def stub_stat(attr, calc, result)
      allow(dsl).to receive(:stat).with(attr, calc) { ->(_, _) { result } }
    end

    before do
      stub_stat(:attr1, :count, 2)
      stub_stat(:attr1, :average, 1)
      stub_stat(:attr2, :maximum, 3)
    end

    it "generates the correct payload for each requested stat" do
      expect(subject).to eq({
        attr1: {count: 2, average: 1},
        attr2: {maximum: 3}
      })
    end
  end

  describe "#calculate_stat" do
    let(:dsl) { Class.new(Graphiti::Resource).new }
    let(:name) { :total }
    let(:function) { dsl.stat(name, :count) }
    let(:expected_count) { 108 }

    context "with default scope and name argument" do
      it "returns correct count" do
        expect_any_instance_of(Graphiti::Adapters::Abstract).to receive(:count).with(scope, :total).and_return(expected_count)
        expect(instance.calculate_stat(name, function)).to eq expected_count
      end
    end

    context "with additional resource-context argument" do
      let(:function) { double(arity: 3) }
      let(:context) { double.as_null_object }
      before { allow(dsl).to receive(:context).and_return(context) }

      it "returns correct count" do
        expect(function).to receive(:call).with(scope, name, context).and_return(expected_count)
        expect(instance.calculate_stat(name, function)).to eq expected_count
      end
    end

    context "with additional resource-context and data argument" do
      let(:function) { double(arity: 4) }
      let(:context) { double.as_null_object }
      before { allow(dsl).to receive(:context).and_return(context) }

      it "returns correct count" do
        expect(function).to receive(:call).with(scope, name, context, data).and_return(expected_count)
        expect(instance.calculate_stat(name, function)).to eq expected_count
      end
    end
  end
end
