require 'spec_helper'
require_relative "../pagination_links/pagination_context.rb"

RSpec.describe Graphiti::Delegates::Pagination do
  include_context "pagination_context"
  let(:instance){ described_class.new(proxy) }

  describe "#links" do
    subject{ instance.links }
    before do
      allow(instance).to receive(:item_count).and_return(current_per_page * total_pages)
      # expect(query).to receive(:pagination_links?).and_return(true)
    end
    it "generates pagination links" do
      expect(subject).to include(:first, :next, :last, :prev)
    end
    it 'generates a link for the first page' do
      expect(subject[:first]).to eq pagination_link(1)
    end
    it 'generates a link for the last page' do
      expect(subject[:last]).to eq pagination_link(total_pages)
    end
    it 'generates a link for the next page' do
      expect(subject[:next]).to eq pagination_link(next_page)
    end
    it 'generates a link for the prev page' do
      expect(subject[:prev]).to eq pagination_link(prev_page)
    end
    context "if on the first page" do
      let(:current_page){ 1 }
      it 'does not have a link for prev' do
        expect(subject[:prev]).to be_nil
      end
    end
    context "if on the last page" do
      let(:current_page){ total_pages }
      it 'does not have a link for next' do
        expect(subject[:next]).to be_nil
      end
    end
    context "if only 1 page" do
      let(:current_page){ 1 }
      let(:total_pages){ 1 }
      it 'does not have a link for next' do
        expect(subject[:next]).to be_nil
      end
      it 'does not have a link for prev' do
        expect(subject[:prev]).to be_nil
      end
    end

    context "when no size param is passed" do
      let(:params){ {  } }
      it 'returns the default size' do
        expect(subject[:first]).to eq(pagination_link(1, size: Graphiti::Scoping::Paginate::DEFAULT_PAGE_SIZE))
      end
    end
  end

  def pagination_link(number, size: current_per_page)
    uri = URI(endpoint[:url])
    uri.query = params.merge(page: { number: number, size: size }).to_query
    uri.to_s
  end


  describe "#pagination_link" do
    subject{ URI(instance.send(:pagination_link, current_page)) }
    it "retains existing params" do
      expect(subject.query).to eq(params.to_query)
    end
  end

  describe "#last_page" do
    subject{ instance.send(:last_page) }
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
  end

end
