require "spec_helper"

RSpec.describe Graphiti::Sideload::HasMany do
  let(:parent_resource_class) { PORO::EmployeeResource }
  let(:resource_class) do
    Class.new(PORO::PositionResource) do
      self.model = PORO::Position
    end
  end
  let(:opts) do
    {
      parent_resource: parent_resource_class,
      resource: resource_class
    }
  end
  let(:name) { :positions }
  let(:instance) { described_class.new(name, opts) }

  describe "#assign" do
    let!(:employee1) { PORO::Employee.new(id: 1) }
    let!(:employee2) { PORO::Employee.new(id: 2) }
    let!(:position1) { PORO::Position.new(id: 1, employee_id: 1) }
    let!(:position2) { PORO::Position.new(id: 2, employee_id: 2) }
    let!(:position3) { PORO::Position.new(id: 3, employee_id: 1) }
    let!(:employees) { [employee1, employee2] }
    let!(:positions) { [position1, position2, position3] }

    it "associates correctly" do
      instance.assign(employees, positions)
      expect(employee1.positions).to eq([position1, position3])
      expect(employee2.positions).to eq([position2])
    end
  end

  describe "#load_params" do
    let(:params) { {} }
    let(:query) { Graphiti::Query.new(instance.resource, params) }
    let(:parents) { [double(foo_id: 8), double(foo_id: 9)] }

    before do
      opts[:primary_key] = :foo_id
      opts[:foreign_key] = :bar_id
      allow(instance.resource).to receive(:_all) { [] }
    end

    it "adds primary key filter" do
      params = instance.load_params(parents, query)
      expect(params).to eq({
        filter: {bar_id: "8,9"}
      })
    end

    it "includes deep query params" do
      resource_class.attribute :a, :string
      params.merge!(filter: {a: "b"}, sort: "-id")
      result = instance.load_params(parents, query)
      expect(result).to eq({
        filter: {bar_id: "8,9", a: "b"},
        sort: [{id: :desc}]
      })
    end
  end
end
