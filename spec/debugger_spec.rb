# frozen_string_literal: true

RSpec.describe Graphiti::Debugger do
  context "when disabled" do
    around do |example|
      old_value = described_class.enabled
      described_class.enabled = false
      example.run
      described_class.enabled = old_value
    end

    describe "#on_render" do
      it "does not add data to chunks Array" do
        expect { described_class.on_render("foo", 0, 100, :foo, {}) }.not_to change(described_class.chunks, :count)
      end
    end

    describe "#on_data" do
      let(:payload) do
        {
          resource: :foo,
          parent: nil,
          params: {},
          results: []
        }
      end

      it "does not add data to chunks Array" do
        expect { described_class.on_data("test", 0, 100, :foo, payload) }.not_to change(described_class.chunks, :count)
      end
    end
  end

  context "when enabled" do
    around do |example|
      old_enabled = described_class.enabled
      old_debug_models = described_class.debug_models
      described_class.enabled = true
      described_class.debug_models = debug_models
      example.run
      described_class.enabled = old_enabled
      described_class.debug_models = old_debug_models
      described_class.chunks = nil
    end

    let(:model) { Class.new { def self.name = "Widget" }.new }

    let(:payload) do
      {
        resource: double(class: double(name: "WidgetResource")),
        parent: nil,
        action: :all,
        params: {},
        results: [model]
      }
    end

    subject(:broadcast) { described_class.on_data("test", 0, 100, :foo, payload) }

    context "and models are not being debugged" do
      let(:debug_models) { false }

      it "does not ask the results for an id" do
        expect(model).to_not receive(:id)

        broadcast
      end
    end

    context "and models are being debugged" do
      let(:debug_models) { true }

      it "logs the id" do
        allow(model).to receive(:id).and_return(1)

        broadcast

        expect(described_class.chunks.join)
          .to include("Returned Models: [Widget, 1]")
      end

      it "logs models that have no id" do
        broadcast

        expect(described_class.chunks.join)
          .to include("Returned Models: [Widget, no id]")
      end
    end
  end
end
