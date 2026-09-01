require "spec_helper"

RSpec.describe "writable guard action" do
  let(:seen) { [] }

  let!(:resource) do
    actions = seen
    Class.new(PORO::ApplicationResource) do
      def self.name
        "GuardEmployeeResource"
      end
      self.model = PORO::Employee
      self.type = :employees
      attribute :first_name, :string, writable: proc {
        actions << Graphiti.context[:action]
        true
      }
      define_singleton_method(:actions) { actions }
    end
  end

  let(:payload) do
    {data: {type: "employees", attributes: {first_name: "Jane"}}}
  end

  before { PORO::DB.clear }

  it "sees :create when the model was not inspected" do
    Graphiti.with_context({}, :all) { resource.build(payload).save }
    expect(seen).to include(:create)
  end

  it "sees :create when the model was inspected first" do
    Graphiti.with_context({}, :all) do
      proxy = resource.build(payload)
      proxy.data
      proxy.save
    end
    expect(seen).to include(:create)
  end
end
