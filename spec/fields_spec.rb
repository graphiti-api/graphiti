require "spec_helper"

RSpec.describe "fields" do
  include_context "resource testing"
  let(:resource) { Class.new(PORO::EmployeeResource) }
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

  # Dot-syntax fieldsets are looked up by the chain of relationship names
  # leading to the resource. Sibling relationships must each start from their
  # parent's chain, not from the chain the previous sibling left behind.
  context "when sibling relationships use dot-syntax fieldsets" do
    let(:resource) do
      Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :other_department,
          resource: PORO::DepartmentResource,
          foreign_key: :other_department_id
      end
    end
    let(:base_scope) { {type: :positions} }

    before do
      PORO::Position.class_eval do
        attr_accessor :other_department, :other_department_id
      end
    end

    let!(:department1) do
      PORO::Department.create(name: "dep1", description: "dep1desc")
    end
    let!(:department2) do
      PORO::Department.create(name: "dep2", description: "dep2desc")
    end
    let!(:position) do
      PORO::Position.create title: "title1",
        rank: 1,
        employee_id: 1,
        department_id: department1.id,
        other_department_id: department2.id
    end

    before do
      params[:include] = "department,other_department"
      params[:fields] = {
        positions: "title",
        # a fieldset for the genuinely nested department.other_department path
        "department.other_department": "name",
        # the second sibling's own fieldset
        other_department: "description"
      }
    end

    it "does not leak the first sibling's name into the second sibling's chain" do
      expect(proxy.as_graphql[:positions][:nodes][0][:otherDepartment])
        .to eq({description: "dep2desc"})
    end
  end
end
