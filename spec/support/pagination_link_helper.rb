require "spec_helper"

RSpec.shared_context "pagination_context", shared_context: :metadata do
  let(:proxy) do
    Graphiti::ResourceProxy.new(resource, scope, query)
  end

  let(:resource) do
    Class.new(Graphiti::Resource) do
      attribute :deprecated, :integer, filterable: true
      belongs_to :bar, resource: self
      has_many :bazzes, resource: self

      def self.endpoint
        {
          path: "/foos",
          full_path: "/api/v2/foos",
          url: "http://localhost:3000/api/v2/foos",
          actions: [:index, :show, :create, :update, :destroy]
        }
      end

      def self.name
        "foos"
      end
    end.new
  end
  let(:query) { Graphiti::Query.new(resource, params) }
  let(:scope) { double(object: collection, pagination: double(size: current_per_page)) }
  let(:pagination_delegate) { Graphiti::Delegates::Pagination.new(proxy) }
  let(:collection) do
    double(total_pages: total_pages,
      prev_page: prev_page,
      next_page: next_page,
      current_per_page: current_per_page)
  end
  let(:total_pages) { 3 }
  let(:prev_page) { 1 }
  let(:next_page) { 3 }
  let(:current_per_page) { 200 }
  let(:current_page) { 2 }
  let(:params) do
    {
      pagination_links: true,
      filter: {
        deprecated: "1"
      },
      page: {
        number: current_page,
        size: current_per_page
      }
    }
  end
  let(:endpoint) do
    resource.endpoint
  end
end
