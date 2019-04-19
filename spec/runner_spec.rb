require "spec_helper"

RSpec.describe Graphiti::Runner do
  let(:resource_class) { PORO::EmployeeResource }
  let(:params) { {} }
  let(:instance) { described_class.new(resource_class, params) }

  describe "#jsonapi_context" do
    let(:ctx) { double("context") }

    before do
      allow(instance).to receive(:jsonapi_context) { ctx }
      allow(instance).to receive(:action_name) { "index" }
    end

    it "sets the context to the given override" do
      instance.wrap_context do
        expect(instance.jsonapi_resource.context).to eq(ctx)
      end
    end
  end

  describe "#proxy" do
    it "returns a proxy with access to records, stats, and query" do
      scope = double(resolve: ["resolved"])
      expect(instance).to receive(:jsonapi_scope).with("foo", {}) { scope }
      proxy = instance.proxy("foo")
      expect(proxy).to be_a(Graphiti::ResourceProxy)
      expect(proxy.query).to be_a(Graphiti::Query)
      expect(proxy.to_a).to eq(["resolved"])
      expect(proxy.stats).to eq({})
    end
  end
end
