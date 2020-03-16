require "spec_helper"

RSpec.describe Graphiti do
  describe ".setup!" do
    let(:resources) do
      [
        double(apply_sideloads_to_serializer: nil),
        double(apply_sideloads_to_serializer: nil)
      ]
    end

    before do
      allow(described_class).to receive(:resources) { resources }
    end

    it "iterates through all resources and applies sideloads to serializers" do
      expect(resources[0]).to receive(:apply_sideloads_to_serializer)
      expect(resources[1]).to receive(:apply_sideloads_to_serializer)
      described_class.setup!
    end
  end
end
