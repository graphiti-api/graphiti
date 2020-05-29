require "spec_helper"

RSpec.describe "A resource with nested stats" do
  include_context "resource testing"

  let!(:employee1) { PORO::Employee.create first_name: "Alice", age: 25 }
  let!(:employee2) { PORO::Employee.create first_name: "Bob", age: 40 }

  let!(:position1) { PORO::Position.create employee_id: employee1.id, rank: 4 }
  let!(:position2) { PORO::Position.create employee_id: employee1.id, rank: 8 }
  let!(:position3) { PORO::Position.create employee_id: employee2.id, rank: 10 }
  let!(:position4) { PORO::Position.create employee_id: employee2.id, rank: 22 }

  let(:state_group_count) { [{id: 10, count: 3}, {id: 11, count: 0}] }

  def jsonapi
    JSON.parse(proxy.to_jsonapi)
  end

  describe "has_many" do
    context "with include directive" do
      let(:resource) do
        Class.new(PORO::EmployeeResource) do
          def self.name
            "PORO::EmployeeResource"
          end

          has_many :positions

          stat age: [:squared], nested_on: :employees do
            squared do |scope, attr, context, employee|
              employee.age * employee.age
            end
          end
        end
      end

      before do
        allow_any_instance_of(PORO::Employee).to receive(:applications_by_state_group_count).and_return(state_group_count)

        params[:include] = "positions"
        params[:stats] = {age: "squared"}
        render
      end

      it "includes the top-level stats" do
        expect(jsonapi["meta"]["stats"]).to be_nil
      end

      it "includes the stats nested on employees" do
        jsonapi["data"].each do |record|
          expect(record["meta"]["stats"]).to_not be_nil
          expect(record["meta"]["stats"]["age"]).to_not be_nil
        end
      end
    end
  end
end
