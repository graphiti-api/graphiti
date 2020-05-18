require "spec_helper"

RSpec.describe Graphiti::Delegates::Pagination do
  include_context "pagination_context"
  let(:instance) { described_class.new(proxy) }

  describe "#links" do
    subject { instance.links }
    before do
      allow(instance).to receive(:item_count).and_return(current_per_page * total_pages)
    end
    it "generates pagination links" do
      expect(subject).to include(:first, :next, :last, :prev)
    end
    it "generates a link for the first page" do
      expect(subject[:first]).to eq pagination_link(1)
    end
    it "generates a link for the last page" do
      expect(subject[:last]).to eq pagination_link(total_pages)
    end
    it "generates a link for the next page" do
      expect(subject[:next]).to eq pagination_link(next_page)
    end
    it "generates a link for the prev page" do
      expect(subject[:prev]).to eq pagination_link(prev_page)
    end
    context "if on the first page" do
      let(:current_page) { 1 }
      it "does not have a link for prev" do
        expect(subject[:prev]).to be_nil
      end
    end
    context "if on the last page" do
      let(:current_page) { total_pages }
      it "does not have a link for next" do
        expect(subject[:next]).to be_nil
      end
    end
    context "if only 1 page" do
      let(:current_page) { 1 }
      let(:total_pages) { 1 }
      it "does not have a link for next" do
        expect(subject[:next]).to be_nil
      end
      it "does not have a link for prev" do
        expect(subject[:prev]).to be_nil
      end
    end

    context "when no size param is passed" do
      let(:params) { {} }
      it "returns the default size" do
        expect(subject[:first]).to eq(pagination_link(1, size: Graphiti::Scoping::Paginate::DEFAULT_PAGE_SIZE))
      end
    end

    context "with included relationship" do
      let(:params) {
        {include: "bar,bazzes", filter: {"bazzes.deprecated" => "foo"}}
      }

      it "preserves include directive and filters on relationships" do
        query = URI.decode_www_form(URI(subject[:first]).query).to_h
        expect(query["include"]).to include("bar")
        expect(query["include"]).to include("bazzes")
        expect(query["filter[bazzes.deprecated]"]).to eq("foo")
      end
    end

    context "with rails parameters" do
      let(:params) {
        {controller: "foos", action: "index", format: "jsonapi"}
      }

      it "removes them" do
        page_links = subject.values
        expect(page_links).to all(satisfy { |v| v["controller=foos"].nil? })
        expect(page_links).to all(satisfy { |v| v["action=index"].nil? })
        expect(page_links).to all(satisfy { |v| v["format=jsonapi"].nil? })
      end
    end
  end

  def pagination_link(number, size: current_per_page)
    uri = URI(endpoint[:url])
    uri.query = params.merge(page: {number: number, size: size}).to_query
    uri.to_s
  end

  describe "#pagination_link" do
    subject { URI(instance.send(:pagination_link, current_page)) }
    it "retains existing params" do
      expect(subject.query).to eq(params.to_query)
    end
  end

  describe "#last_page" do
    subject { instance.send(:last_page) }
    it "returns 1 page if item_count is 1 and page_size is 1" do
      allow(instance).to receive(:item_count).and_return(1)
      allow(instance).to receive(:page_size).and_return(1)
      expect(subject).to eq 1
    end

    it "returns 2 pages if item_count 3 and page_size is 2" do
      allow(instance).to receive(:item_count).and_return(3)
      allow(instance).to receive(:page_size).and_return(2)
      expect(subject).to eq 2
    end

    context "when item_count is 0" do
      it "returns nil" do
        allow(instance).to receive(:item_count).and_return(0)
        allow(instance).to receive(:page_size).and_return(2)
        expect(subject).to eq nil
      end
    end

    context "when page_size is 0" do
      it "returns nil" do
        allow(instance).to receive(:item_count).and_return(3)
        allow(instance).to receive(:page_size).and_return(0)
        expect(subject).to eq nil
      end
    end
  end

  describe "#item_count" do
    subject { instance.send(:item_count) }
    let(:expected_item_count) { 1 }

    it "returns 0 if resource.stat(:total, :count) is nil" do
      expect(proxy.scope).to receive(:unpaginated_object)
      expect(proxy.resource).to receive(:stat).with(:total, :count).and_return(lambda { |obj, meth| nil })
      expect(subject).to eq 0
    end

    it "returns the value of resource.stat(:total, :count)" do
      expect(proxy.scope).to receive(:unpaginated_object)
      expect(proxy.resource).to receive(:stat).with(:total, :count).and_return(lambda { |obj, meth| expected_item_count })
      expect(subject).to eq expected_item_count
    end
  end
end
