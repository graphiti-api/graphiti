require "spec_helper"

RSpec.describe Graphiti::ResourceProxy do
  let(:instance) { described_class.new(double, double, double, **{}) }
  describe "pagination" do
    subject { instance.pagination }
    it "is a pagination delegate" do
      expect(subject).to be_kind_of(Graphiti::Delegates::Pagination)
    end
  end

  describe "caching" do
    let(:resource) { double }
    let(:query) { double(cache_key: "query-hash") }
    let(:scope) { double(cache_key: "scope-hash", cache_key_with_version: "scope-hash-123456") }

    subject { described_class.new(resource, scope, query, **{}) }

    it "cache_key combines query and scope cache keys" do
      cache_key = subject.cache_key
      expect(cache_key).to eq("scope-hash/query-hash")
    end

    it "generates stable etag" do
      instance1 = described_class.new(resource, scope, query, **{})
      instance2 = described_class.new(resource, scope, query, **{})

      expect(instance1.etag).to be_present
      expect(instance1.etag).to start_with("W/")

      expect(instance2.etag).to be_present
      expect(instance2.etag).to start_with("W/")

      expect(instance1.etag).to eq(instance2.etag)
    end
  end
end
