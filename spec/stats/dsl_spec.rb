require "spec_helper"

RSpec.describe Graphiti::Stats::DSL do
  let(:config) { :myattr }
  let(:adapter) { Graphiti::Adapters::Null.new(resource.new) }
  let(:instance) { described_class.new(adapter, config) }
  let!(:resource) { Class.new(Graphiti::Resource) }

  describe ".new" do
    it "sets name" do
      expect(instance.name).to eq(:myattr)
    end

    it "sets calculations" do
      expect(instance.calculations).to eq({})
    end

    context "when passed a hash" do
      it "applies defaults" do
        expect_any_instance_of(described_class)
          .to receive(:count!).and_call_original
        instance = described_class.new(adapter, myattr: [:count])
        expect(instance.calculations).to have_key(:count)
      end
    end
  end

  describe "#method_missing" do
    it "sets calculation" do
      prc = ->(_, _) { 1 }
      instance.foo(&prc)
      expect(instance.calculations[:foo]).to eq(prc)
    end
  end

  describe "#calculation" do
    before do
      instance.count!
    end

    context "when passed a symbol" do
      it "returns the calculation" do
        expect(instance.calculation(:count)).to respond_to(:call)
      end
    end

    context "when passed a string" do
      it "returns the calculation" do
        expect(instance.calculation("count")).to respond_to(:call)
      end
    end

    context "when no calculation found" do
      it "raises an error" do
        expect { instance.calculation(:foo) }
          .to raise_error(Graphiti::Errors::StatNotFound, "No stat configured for calculation :foo on attribute :myattr")
      end
    end
  end
end
