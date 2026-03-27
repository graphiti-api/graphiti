require "spec_helper"

RSpec.describe "Nullification feature" do
  let(:employee_resource) { PORO::EmployeeResource }
  let(:position_resource) { PORO::PositionResource }

  before { PORO::DB.clear }

  context "belongs_to relationship" do
    it "nullifies the relationship when given { data: null }" do
      # Create a department and a position belonging to it
      department = PORO::Department.create(name: "Engineering")
      position = PORO::Position.create(title: "Dev", department_id: department.id)
      expect(position.department_id).to eq(department.id)

      # Nullify the department relationship
      payload = {
        data: {
          type: "positions",
          id: position.id.to_s,
          relationships: {
            department: { data: nil }
          }
        }
      }
      resource = position_resource.find(payload)
      expect(resource.update_attributes).to eq(true)
      expect(resource.data.department_id).to be_nil
    end
  end

  context "has_many relationship" do
    it "nullifies the has_many relationship when given { data: null }" do
      # Create an employee with positions
      employee = PORO::Employee.create(first_name: "Jane")
      pos1 = PORO::Position.create(title: "Dev", employee_id: employee.id)
      pos2 = PORO::Position.create(title: "QA", employee_id: employee.id)
      expect([pos1.employee_id, pos2.employee_id]).to all(eq(employee.id))

      # Nullify the positions relationship
      payload = {
        data: {
          type: "employees",
          id: employee.id.to_s,
          relationships: {
            positions: { data: nil }
          }
        }
      }
      resource = employee_resource.find(payload)
      expect(resource.update_attributes).to eq(true)
      # All positions should be disassociated
      expect(PORO::Position.find(pos1.id).employee_id).to be_nil
      expect(PORO::Position.find(pos2.id).employee_id).to be_nil
    end
  end
end
