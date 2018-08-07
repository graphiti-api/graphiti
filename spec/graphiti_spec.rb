require 'spec_helper'

RSpec.describe Graphiti do
  describe '.check!' do
    before do
      described_class.instance_variable_set(:@resources, [])
      described_class.resources << PORO::EmployeeResource
    end

    it 'checks all sideloads' do
      expect(PORO::EmployeeResource.sideload(:positions))
        .to receive(:check!)
      described_class.check!
    end
  end
end
