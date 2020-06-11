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
    let(:proxy) { instance.proxy("foo") }
    let(:scope) { double(resolve: ["resolved"]) }
    before { allow(instance).to receive(:jsonapi_scope).and_return(scope) }

    it "returns a proxy with access to records, stats, and query" do
      expect(instance).to receive(:jsonapi_scope).with("foo", {}) { scope }
      expect(proxy).to be_a(Graphiti::ResourceProxy)
      expect(proxy.query).to be_a(Graphiti::Query)
      expect(proxy.to_a).to eq(["resolved"])
      expect(proxy.stats).to eq({})
    end

    describe "the proxy's query" do
      subject(:query) { proxy.query }

      context "when an action is provided" do
        let(:instance) { described_class.new(resource_class, params, nil, :action) }
        it { expect(query.action).to eq(:action) }
      end

      context "when a query is provided" do
        let(:provided_query) { double(:provided_query) }
        let(:instance) { described_class.new(resource_class, params, provided_query) }

        it { is_expected.to eq(provided_query) }
      end
    end
  end
end
