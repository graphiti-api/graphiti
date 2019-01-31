require 'spec_helper'

RSpec.describe Graphiti::ResourceProxy do
  let(:instance){ described_class.new(double, double, double, {  }) }
  describe "pagination" do
    subject{ instance.pagination }
    it "is a pagination delegate" do
      expect(subject).to be_kind_of(Graphiti::Delegates::Pagination)
    end
  end
end
