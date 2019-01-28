require 'spec_helper'

RSpec.describe Graphiti::Util::AttributeCheck do
  describe 'with inheritance' do
    it 'works for inherited attributes' do
      expect(
        described_class.run(PORO::VisaResource.new, :number, :readable, false, false)
      ).to eq(PORO::VisaResource.all_attributes[:number])
    end
    it 'works for defined attributes' do
      expect(
        described_class.run(PORO::VisaResource.new, :visa_only_attr, :readable, false, false)
      ).to eq(PORO::VisaResource.all_attributes[:visa_only_attr])
    end
  end
end
