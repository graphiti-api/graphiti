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

    subject { described_class.new(resource, scope, query, **{cache_tag: :cache_tag}) }

    it "cache_key combines query and scope cache keys if no tags are set" do
      cache_key = subject.cache_key
      expect(cache_key).to eq("scope-hash/query-hash")
    end

    it "cache_key combines query, scope and tag cache keys if a tag is set" do
      allow(resource).to receive(:cache_tag).and_return("tag_value")

      cache_key = subject.cache_key
      expect(cache_key).to eq("scope-hash/query-hash/tag_value")
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
