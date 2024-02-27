# frozen_string_literal: true

require "spec_helper"

RSpec.describe "relationship identifiers" do
  include_context "resource testing"

  # let(:base_scope) { { type: :positions } }
  let!(:employee) { PORO::Employee.create }
  let!(:employee2) { PORO::Employee.create }
  let!(:position1) do
    PORO::Position.create employee_id: employee.id,
      department_id: department1.id
  end
  let!(:position2) do
    PORO::Position.create employee_id: employee.id,
      department_id: department2.id
  end
  let!(:department1) { PORO::Department.create }
  let!(:department2) { PORO::Department.create }
  let!(:bio1) { PORO::Bio.create(employee_id: employee.id) }
  let!(:bio2) { PORO::Bio.create(employee_id: employee.id) }
  let!(:team1) do
    PORO::Team.create team_memberships: [
      PORO::TeamMembership.new(employee_id: employee.id, team_id: 1)
    ]
  end
  let!(:team2) do
    PORO::Team.create team_memberships: [
      PORO::TeamMembership.new(employee_id: employee.id, team_id: 2)
    ]
  end

  describe "has_many" do
    context "with default" do
      let(:resource) do
        Class.new(PORO::TeamResource) do
          def self.name
            "PORO::TeamResource"
          end

          has_many :employees
        end
      end

      before do
        allow_any_instance_of(PORO::Team).to receive(:employees) { [employee, employee2] }
        render
      end

      it "does not include anything" do
        expect do
          included("employees")
        end.to raise_error(GraphitiSpecHelpers::Errors::NoSideloads)
      end

      it "specifies meta[:included] = false" do
        jsonapi_data.each do |record|
          expect(record.relationships["employees"]["meta"]["included"]).to eq(false)
        end
      end

      it "does not includes relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employees"]["data"]
          expect(data).to be_nil
        end
      end
    end
    context "with include directive" do
      let(:resource) do
        Class.new(PORO::TeamResource) do
          def self.name
            "PORO::TeamResource"
          end

          has_many :employees do
            scope do |employee_ids|
              {
                type: :employees,
                conditions: {employee_id: employee_ids}
              }
            end
          end
        end
      end

      before do
        params[:include] = "employees"
        allow_any_instance_of(PORO::Team).to receive(:employees) { [employee, employee2] }
        render
      end

      it "includes employees" do
        expect(included("employees").map(&:id)).to eq([1, 2])
      end

      it "includes relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employees"]["data"]
          expect(data).to_not be_nil
          expect(data.pluck(:type).uniq).to match_array(["employees"])
          expect(data.pluck(:id).uniq).to match_array(%w[1 2])
        end
      end
    end

    context "without include directive and always_include_resource_ids: true" do
      let(:resource) do
        Class.new(PORO::TeamResource) do
          def self.name
            "PORO::TeamResource"
          end

          has_many :employees, always_include_resource_ids: true do
            scope do |employee_ids|
              {
                type: :employees,
                conditions: {employee_id: employee_ids}
              }
            end
          end
        end
      end

      before do
        allow_any_instance_of(PORO::Team).to receive(:employees) { [employee, employee2] }
        render
      end

      it "does not include anything" do
        expect do
          included("employees")
        end.to raise_error(GraphitiSpecHelpers::Errors::NoSideloads)
      end

      it "includes relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employees"]["data"]
          expect(data).to_not be_nil
          expect(data.pluck(:type).uniq).to match_array(["employees"])
          expect(data.pluck(:id).uniq).to match_array(%w[1 2])
        end
      end
    end
  end

  describe "belongs_to" do
    context "with include directive" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          belongs_to :employee
        end
      end
      before do
        params[:include] = "employee"
        render
      end

      it "works" do
        expect(included("employees").map(&:id)).to eq([1])
      end

      it "has relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employee"]["data"]

          expect(data[:type]).to eq("employees")
          expect(data[:id]).to eq("1")
        end
      end
    end

    context "with defaults" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          belongs_to :employee
        end
      end

      before do
        allow_any_instance_of(PORO::Position).to receive(:employee) { employee }
        render
      end

      # Currently disabled as causes an N+1
      xit "has relationship ids" do
        jsonapi_data.each do |record|
          data = record.relationships["employee"]["data"]

          expect(data[:type]).to eq("employees")
          expect(data[:id]).to eq("1")
        end
      end
    end

    context "with always_include_resource_ids: false" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          belongs_to :employee, always_include_resource_ids: false do
            scope do |employee_ids|
              {
                type: :employees,
                conditions: {id: employee_ids}
              }
            end
          end
        end
      end

      before do
        allow_any_instance_of(PORO::Position).to receive(:employee) { employee }
        render
      end

      it "has no relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employee"]
          expect(data.keys).to_not include("data")
        end
      end
    end
  end
end
