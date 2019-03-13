require "spec_helper"

RSpec.describe Graphiti::Scoping::Filter do
  let(:params)   { { filter: { age: { gte: 33, lte: 45 }}} }
  let(:query)    { Graphiti::Query.new(resource, params) }
  let(:instance) { described_class.new(resource, query.hash, []) }
  let(:resource) { PORO::EmployeeResource.new }

  describe "#apply" do
    before do
      allow(instance).to receive(:missing_required_filters) { [] }
      allow(instance).to receive(:missing_dependent_filters) { [] }
    end

    it "works correctly" do
      expect(instance).to receive(:normalize_param)
        .with(resource.filters.slice(:age), params.dig(:filter, :age))
        .and_return(params.dig(:filter, :age).to_a)

      expect(resource.adapter).to receive(:send)
        .with(:filter_integer_gte, [], :age, [33])
        .at_least(1).times

      expect(resource.adapter).to receive(:send)
        .with(:filter_integer_lte, nil, :age, [45])
        .at_least(1).times

      instance.apply
    end
  end
end
