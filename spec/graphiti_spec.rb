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

  describe ".context" do
    it "reads :namespace as a deprecated alias of :action" do
      described_class.with_context(double, :index) do
        expect(Graphiti::DEPRECATOR).to receive(:deprecation_warning)
          .with(:"context[:namespace]", /current_action/, anything)
        expect(described_class.context[:namespace]).to eq(:index)
      end
    end

    it "writes :namespace through to :action" do
      described_class.with_context(double, :index) do
        allow(Graphiti::DEPRECATOR).to receive(:deprecation_warning)
        described_class.context[:namespace] = :update
        expect(described_class.context[:action]).to eq(:update)
      end
    end
  end
end
