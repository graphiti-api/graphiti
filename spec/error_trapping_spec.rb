require "spec_helper"

RSpec.describe "trapping errors" do
  let(:klass) do
    Class.new(PORO::ApplicationResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end

  let(:position_resource) do
    Class.new(PORO::ApplicationResource) do
      def self.name
        "PORO::PositionResource"
      end
    end
  end

  let!(:employee) { PORO::Employee.create }
  let!(:position) { PORO::Position.create(employee_id: employee.id) }

  describe "when error happens during sideload parameter building" do
    before do
      klass.has_many :positions, resource: position_resource do
        params do
          raise "asdf"
        end
      end
    end

    it "traps correctly" do
      expect {
        klass.all(include: "positions").data
      }.to raise_error(Graphiti::Errors::SideloadParamsError, /PORO::EmployeeResource: error occurred while sideloading "positions"!/)
    end
  end

  describe "when error happens during sideload query building" do
    before do
      klass.has_many :positions, resource: position_resource
    end

    it "traps correctly" do
      expect {
        klass.all(include: "positions").data
      }.to raise_error(Graphiti::Errors::SideloadQueryBuildingError, /PORO::EmployeeResource: error occurred while sideloading "positions"!/)
    end
  end

  describe "when error happens during sideload assignment" do
    before do
      position_resource.filter :employee_id, :integer
      klass.has_many :positions, resource: position_resource do
        assign do
          raise "asd"
        end
      end
    end

    it "traps correctly" do
      expect {
        klass.all(include: "positions").data
      }.to raise_error(Graphiti::Errors::SideloadAssignError, /PORO::EmployeeResource: error occurred while sideloading "positions"!/)
    end
  end
end
