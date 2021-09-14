require "spec_helper"

RSpec.describe "fields" do
  include_context "resource testing"
  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end
  let(:base_scope) { {type: :employees} }

  let!(:employee) do
    PORO::Employee.create(first_name: "John", last_name: "Doe")
  end

  subject(:attributes) { json["data"][0]["attributes"] }

  it "does not limit without fields param" do
    render
    expect(attributes.keys).to eq(%w[first_name last_name age])
  end

  it "limits to only the requested fields" do
    params[:fields] = {employees: "first_name,last_name"}
    render
    expect(attributes.keys).to eq(%w[first_name last_name])
  end

  context "when a field is guarded" do
    before do
      params[:fields] = {authors: "first_name,salary"}
    end

    context "and the guard does not pass" do
      let(:ctx) { double(current_user: "non-admin").as_null_object }

      it "does not render the field" do
        Graphiti.with_context ctx, {} do
          render
          expect(attributes.keys).to_not include("salary")
        end
      end

      context "and running in GraphQL context" do
        it "raises error" do
          expect {
            Graphiti.with_context ctx, {} do
              Graphiti.context[:graphql] = true
              render
              expect(attributes.keys).to_not include("salary")
            end
          }.to raise_error(::Graphiti::Errors::UnreadableAttribute, /salary/)
        end
      end
    end

    context "and the guard passes" do
      let(:ctx) { double(current_user: "admin").as_null_object }

      it "renders the field" do
        Graphiti.with_context ctx, {} do
          render
          expect(attributes.keys).to include("salary")
        end
      end
    end
  end

  context "with sideload" do
    let!(:department) { PORO::Department.create }
    let!(:position) { PORO::Position.create employee_id: employee.id, department_id: department.id }
    let!(:bio) { PORO::Bio.create(employee_id: employee.id) }

    before do
      resource.class_eval do
        allow_sideload :positions, type: :has_many do
          scope do |employee_ids|
            {
              type: :positions,
              conditions: {employee_id: employee_ids}
            }
          end

          assign_each do |employee, positions|
            positions.select { |p| p.employee_id == employee.id }
          end
        end

        has_one :bio do
          scope do |employee_ids|
            {
              type: :bios,
              conditions: {employee_id: employee_ids}
            }
          end
        end
      end
      params[:include] = "positions,bio"
    end

    context "with only attribute in fields param" do
      before { params[:fields] = { employees: "first_name" } }

      it 'limits relationships with fields param' do
        render
        expect(d[0].relationships).to be_nil
      end
    end

    context "with only relationship in fields param" do
      before { params[:fields] = { employees: "positions" } }

      it 'only allows the relationship referenced in fields param' do
        render
        expect(d[0].relationships.keys).to contain_exactly("positions")
      end
    end
  end
end
