require "spec_helper"

RSpec.describe ".boolean_attribute" do
  let(:klass) do
    Class.new(Graphiti::Serializer) do
      type :authors

      boolean_attribute :celebrity?
    end
  end

  let(:author) { double(id: 1) }
  let(:proxy) { double(nested_stats: {}) }
  let(:resource) { klass.new(resource: double(type: "klass"), object: author, proxy: proxy) }

  subject { resource.as_jsonapi[:attributes] }

  before do
    allow(author).to receive(:celebrity?) { true }
  end

  it { is_expected.to eq(is_celebrity: true) }

  context "when supplied a block" do
    before do
      klass.class_eval do
        boolean_attribute :alive? do
          "yesss"
        end
      end
    end

    it { is_expected.to include(is_alive: "yesss") }
  end
end
