require 'spec_helper'

RSpec.describe 'polymorphic resources' do
  let(:klass) { Class.new(PORO::CreditCardResource) }
  let(:instance) { klass.new }

  describe '#serializer_for' do
    it 'returns the serializer of the child resource associated to the given model' do
      expect(instance.serializer_for(PORO::Visa.new))
        .to eq(PORO::VisaResource.serializer)
    end

    context 'when resource not found' do
      it 'raises an error' do
        expect {
          instance.serializer_for(PORO::Employee.new)
        }.to raise_error(JsonapiCompliable::Errors::PolymorphicChildNotFound)
      end
    end
  end

  describe '#associate' do
    let(:parent) { PORO::Visa.new(id: 1) }
    let(:child) { PORO::VisaReward.new(id: 100, visa_id: 1) }
    subject(:associate) do
      instance.associate(parent, child, :visa_rewards, :has_many)
    end

    it 'associates via the child resource' do
      associate
      expect(parent.visa_rewards).to eq([child])
    end

    context 'when child resource does not have the association' do
      let(:parent) { PORO::Mastercard.new(id: 1) }

      it 'does nothing' do
        expect(associate).to be_nil
      end
    end
  end

  describe 'inheritance' do
    it 'infers the right type' do
      expect(PORO::VisaResource.type).to eq(:visas)
    end

    it 'infers the right model' do
      expect(PORO::VisaResource.model).to eq(PORO::Visa)
    end

    it 'marks itself as a polymorphic child' do
      expect(PORO::VisaResource.polymorphic_child?).to eq(true)
    end
  end
end
