require "spec_helper"

RSpec.describe "linkage with a colliding relationship name" do
  let!(:classification_resource) do
    Class.new(PORO::ApplicationResource) do
      def self.name
        "LkClassificationResource"
      end
      self.model = PORO::Classification
      self.type = :classifications
      attribute :description, :string
    end
  end

  let!(:position_resource) do
    cls = classification_resource
    Class.new(PORO::ApplicationResource) do
      def self.name
        "LkPositionResource"
      end
      self.model = PORO::Position
      self.type = :positions
      attribute :employee_id, :integer, only: [:filterable]
      attribute :classification_id, :integer, only: [:filterable]
      belongs_to :classification, resource: cls, foreign_key: :classification_id
    end
  end

  let!(:employee_resource) do
    cls = classification_resource
    pos = position_resource
    Class.new(PORO::ApplicationResource) do
      def self.name
        "LkEmployeeResource"
      end
      self.model = PORO::Employee
      self.type = :employees
      attribute :first_name, :string
      attribute :classification_id, :integer, only: [:filterable]
      belongs_to :classification, resource: cls, foreign_key: :classification_id
      has_many :positions, resource: pos, foreign_key: :employee_id
    end
  end

  before do
    PORO::Position.class_eval { attr_accessor :classification_id, :classification }
    PORO::DB.clear
    PORO::Classification.create(description: "c1")
    employee = PORO::Employee.create(first_name: "A", classification_id: 1)
    PORO::Position.create(employee_id: employee.id, classification_id: 1)
  end

  def employee_classification(params)
    json = JSON.parse(employee_resource.all(params).to_jsonapi)
    json["data"][0]["relationships"]["classification"]["data"]
  end

  it "renders the linkage from the foreign key" do
    expect(employee_classification(include: "positions")).to eq({"type" => "classifications", "id" => "1"})
  end

  it "still renders it when a nested include shares the relationship name" do
    expect(employee_classification(include: "positions.classification")).to eq({"type" => "classifications", "id" => "1"})
  end
end
