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
end
