require "spec_helper"

RSpec.describe "deep filter vs dedup" do
  let!(:position_resource) do
    Class.new(PORO::ApplicationResource) do
      def self.name
        "RtPositionResource"
      end
      self.model = PORO::Position
      self.type = :positions
      attribute :employee_id, :integer, only: [:filterable]
      attribute :title, :string
      attribute :rank, :integer
    end
  end

  let!(:employee_resource) do
    positions = position_resource
    klass = Class.new(PORO::ApplicationResource) do
      def self.name
        "RtEmployeeResource"
      end
      self.model = PORO::Employee
      self.type = :employees
      attribute :first_name, :string
      has_many :positions, resource: positions, foreign_key: :employee_id
    end
    positions.belongs_to :employee, resource: klass, foreign_key: :employee_id
    klass
  end

  before do
    PORO::DB.clear
    employee = PORO::Employee.create(first_name: "A")
    PORO::Position.create(employee_id: employee.id, rank: 1, title: "one")
    PORO::Position.create(employee_id: employee.id, rank: 2, title: "two")
  end

  def positions_for(params)
    json = JSON.parse(employee_resource.all(params).to_jsonapi)
    json["data"][0]["relationships"]["positions"]["data"].map { |r| r["id"] }.sort
  end

  it "narrows on the shallow path" do
    expect(positions_for(include: "positions", filter: {"positions.rank" => 1})).to eq(["1"])
  end

  it "still narrows when the include round-trips back to positions" do
    expect(positions_for(include: "positions.employee.positions", filter: {"positions.rank" => 1})).to eq(["1"])
  end
end
