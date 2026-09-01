# frozen_string_literal: true

require "spec_helper"

RSpec.describe "overriding an inherited relationship" do
  include_context "resource testing"

  let(:other_resource) do
    Class.new(PORO::DepartmentResource) do
      def self.name
        "PORO::OtherDepartmentResource"
      end

      self.model = PORO::Department
      self.type = :other_departments
    end
  end

  # PORO::PositionResource already declares `belongs_to :department`
  let(:resource) do
    other = other_resource
    Class.new(PORO::PositionResource) do
      def self.name
        "PORO::PositionResource"
      end

      belongs_to :department, resource: other
    end
  end
  let(:base_scope) { {type: :positions} }

  let!(:department) { PORO::Department.create(name: "Engineering") }
  let!(:position) { PORO::Position.create(title: "Developer", department_id: department.id) }

  it "renders the subclass's resource, not the one it inherited" do
    render

    expect(jsonapi_data[0].relationships["department"]["data"]["type"])
      .to eq("other_departments")
  end

  it "leaves the parent's serializer alone" do
    resource # declare the override

    expect(PORO::PositionResource.serializer.relationship_sideloads[:department])
      .to eq(PORO::PositionResource.sideloads[:department])
  end

  it "does not replace a relationship block the application wrote by hand" do
    serializer = Class.new(Graphiti::Serializer) do
      relationship :department do
        data { nil }
      end
    end
    hand_written = serializer.relationship_blocks[:department]

    klass = Class.new(PORO::PositionResource) do
      def self.name
        "PORO::PositionResource"
      end
    end
    klass.serializer = serializer
    klass.belongs_to :department, resource: PORO::DepartmentResource

    expect(klass.serializer.relationship_blocks[:department]).to equal(hand_written)
  end
end
