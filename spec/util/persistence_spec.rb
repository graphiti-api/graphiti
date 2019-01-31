require 'spec_helper'

RSpec.describe Graphiti::Util::Persistence do
  describe 'with inheritance' do
    context 'using base class' do
      it 'can be initialized' do
        expect(
          described_class.new(
            PORO::CreditCardResource.new, { type: 'visas' },
            { number: '4222222222222222', visa_only_attr: 'TestInheritance' },
            {}, nil
          )
        ).to be_a(described_class)
      end
      it 'fails for unknown attributes' do
        expect do
          described_class.new(
            PORO::CreditCardResource.new, { type: 'visas' },
            { random_attr: 'RandomValue' }, {}, nil
          )
        end.to raise_error(Graphiti::Errors::AttributeError)
      end
    end
  end
end
