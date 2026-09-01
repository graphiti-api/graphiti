require "spec_helper"

# Inspecting the model before saving keeps the sideposted foreign key out of the hash the
# attributes callbacks receive. apply_derived_attributes still writes it onto the model.
RSpec.describe "attributes callbacks with a sideposted parent" do
  let(:fired) { [] }

  let!(:classification_resource) do
    Class.new(PORO::ApplicationResource) do
      def self.name
        "ScClassificationResource"
      end
      self.model = PORO::Classification
      self.type = :classifications
      attribute :description, :string
    end
  end

  let!(:employee_resource) do
    classifications = classification_resource
    recorder = fired
    Class.new(PORO::ApplicationResource) do
      def self.name
        "ScEmployeeResource"
      end
      self.model = PORO::Employee
      self.type = :employees
      attribute :first_name, :string
      attribute :classification_id, :integer, only: [:writable]
      belongs_to :classification, resource: classifications
      before_attributes { |attributes| recorder << attributes.keys }
    end
  end

  def payload(id = nil)
    data = {
      type: "employees",
      attributes: {first_name: "Jane"},
      relationships: {
        classification: {data: {type: "classifications", "temp-id": "abc", method: "create"}}
      }
    }
    data[:id] = id.to_s if id
    {
      data: data,
      included: [{type: "classifications", "temp-id": "abc", attributes: {description: "x"}}]
    }
  end

  before { PORO::DB.clear }

  context "creating" do
    it "fires once with the derived foreign key included" do
      employee_resource.build(payload).save

      expect(fired).to eq([[:first_name, :classification_id]])
    end

    it "fires without the foreign key when the model is inspected first" do
      proxy = employee_resource.build(payload)
      proxy.data
      proxy.save

      expect(fired).to eq([[:first_name]])
    end
  end

  context "updating" do
    let!(:employee) { PORO::Employee.create(first_name: "old") }

    it "fires once with the derived foreign key included" do
      employee_resource.find(payload(employee.id)).update_attributes

      expect(fired).to eq([[:first_name, :classification_id]])
    end

    it "fires without the foreign key when the model is inspected first" do
      proxy = employee_resource.find(payload(employee.id))
      proxy.assign_attributes(payload(employee.id))
      proxy.data
      proxy.update

      expect(fired).to eq([[:first_name]])
    end
  end
end
