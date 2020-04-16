require "spec_helper"

RSpec.describe "polymorphic resources" do
  # Inheriting causes us to think this class is a polymorphic
  # child. Let it know this is not so, we just want a subclass for testing
  let(:klass) do
    Class.new(PORO::CreditCardResource) do
      self.polymorphic_child = false
    end
  end
  let(:instance) { klass.new }

  describe "#serializer_for" do
    it "returns the serializer of the child resource associated to the given model" do
      expect(instance.serializer_for(PORO::Visa.new))
        .to eq(PORO::VisaResource.serializer)
      expect(instance.serializer_for(PORO::GoldVisa.new))
        .to eq(PORO::GoldVisaResource.serializer)
    end

    context "when a polymorphic child" do
      let(:child) { Class.new(klass) }

      it "uses the child serializer" do
        expect(child.new.serializer_for(PORO::Visa.new))
          .to eq(child.serializer)
      end
    end

    context "when resource not found" do
      it "raises an error" do
        expect {
          instance.serializer_for(PORO::Employee.new)
        }.to raise_error(Graphiti::Errors::PolymorphicResourceChildNotFound)
      end
    end
  end

  describe "#associate" do
    let(:parent) { PORO::Visa.new(id: 1) }
    let(:child) { PORO::VisaReward.new(id: 100, visa_id: 1) }
    subject(:associate) do
      instance.associate(parent, child, :visa_rewards, :has_many)
    end

    it "associates via the child resource" do
      associate
      expect(parent.visa_rewards).to eq([child])
    end

    context "when child resource does not have the association" do
      let(:parent) { PORO::Mastercard.new(id: 1) }

      it "does nothing" do
        expect(associate).to be_nil
      end
    end
  end

  describe ".sideload" do
    it "scans children" do
      expect(klass.sideload(:visa_rewards))
        .to eq(PORO::VisaResource.sideload(:visa_rewards))
    end

    context "when a child" do
      it "does not scan other children" do
        expect(Class.new(klass).sideload(:visa_rewards)).to be_nil
      end
    end
  end

  describe "inheritance" do
    it "infers the right type" do
      expect(PORO::VisaResource.type).to eq(:visas)
    end

    it "infers the right model" do
      expect(PORO::VisaResource.model).to eq(PORO::Visa)
    end

    it "marks itself as a polymorphic child" do
      expect(PORO::VisaResource.polymorphic_child?).to eq(true)
    end
  end
end
