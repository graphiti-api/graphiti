require "spec_helper"

RSpec.describe Graphiti::Sideload::PolymorphicBelongsTo do
  let(:klass) { Class.new(described_class) }
  let(:parent_resource_class) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end
  let(:resource_class) do
    Class.new(PORO::CreditCardResource) do
      self.polymorphic_child = false

      def self.name
        "PORO::CreditCardResource"
      end
    end
  end
  let(:opts) do
    {
      parent_resource: parent_resource_class,
      resource: resource_class
    }
  end
  let(:name) { :foo }
  let(:instance) { klass.new(name, opts) }

  describe "#infer_foreign_key" do
    it "is inferred from name (no model on the parent)" do
      expect(instance.infer_foreign_key).to eq(:foo_id)
    end
  end

  describe "#child_for_type" do
    let(:child1) { double(resource: double(type: "foos")) }
    let(:child2) { double(resource: double(type: "bars")) }

    before do
      instance.children = {foo: child1, bar: child2}
    end

    it "returns the child sideload that has a resource with the given type" do
      expect(instance.child_for_type("bars")).to eq(child2)
    end
  end

  describe "#resolve" do
    let(:query) { double("query") }
    let(:graph_parent) { double("graph_parent") }
    let(:parent) { double("parent", credit_card_id: "credit_cards") }
    let(:parents) { [parent] }
    let(:child_sideload) { double("child", group_name: :credit_cards, resource: double("resource")) }

    before do
      allow(instance.grouper).to receive(:field_name).and_return(:credit_card_id)
      instance.children = {credit_cards: child_sideload}
      allow(instance).to receive(:remove_invalid_sideloads) { query }
    end

    it "resolves each group synchronously by default" do
      expect(instance).not_to receive(:future_resolve)
      expect(child_sideload).to receive(:resolve).with(parents, query, graph_parent)
      instance.resolve(parents, query, graph_parent)
    end

    context "when Graphiti.config.concurrency is true" do
      before { allow(Graphiti.config).to receive(:concurrency).and_return(true) }

      it "resolves via a future" do
        expect(instance).to receive(:future_resolve)
          .with(parents, query, graph_parent).and_return(Concurrent::Promises.fulfilled_future(nil))
        instance.resolve(parents, query, graph_parent)
      end
    end
  end
end
