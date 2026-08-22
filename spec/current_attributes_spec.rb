require "spec_helper"
require "active_support/current_attributes"

module CurrentAttributesTest
  class Current < ActiveSupport::CurrentAttributes
    attribute :user
  end
end

RSpec.describe "CurrentAttributes propagation into concurrent sideloads" do
  include ConcurrencyHarness

  include_context "resource testing"

  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end
  let(:base_scope) { {type: :employees} }

  let!(:employee) { PORO::Employee.create }
  let!(:position) { PORO::Position.create(employee_id: employee.id) }

  around do |example|
    PORO::Employee.class_eval { attr_accessor :probe_positions }
    example.run
  ensure
    PORO::Employee.class_eval do
      remove_method :probe_positions
      remove_method :probe_positions=
    end
  end

  before do
    allow(Graphiti.config).to receive(:concurrency).and_return(true)
    with_thread_pool(max_threads: 2)
  end

  after { CurrentAttributesTest::Current.reset }

  it "carries Current values onto the pool thread" do
    observed = nil
    resource.has_many :probe_positions, resource: PORO::PositionResource, foreign_key: :employee_id do
      scope do |employee_ids|
        observed = {thread: Thread.current.object_id, user: CurrentAttributesTest::Current.user}
        {type: :positions, conditions: {employee_id: employee_ids}}
      end
    end

    CurrentAttributesTest::Current.user = "jeff"
    params[:include] = "probe_positions"
    resource.all(params).to_a

    expect(observed[:thread]).to_not eq(Thread.current.object_id)
    expect(observed[:user]).to eq("jeff")
  end

  it "keeps a sideload's writes off the request thread" do
    resource.has_many :probe_positions, resource: PORO::PositionResource, foreign_key: :employee_id do
      scope do |employee_ids|
        CurrentAttributesTest::Current.user = "someone else"
        {type: :positions, conditions: {employee_id: employee_ids}}
      end
    end

    CurrentAttributesTest::Current.user = "jeff"
    params[:include] = "probe_positions"
    resource.all(params).to_a

    expect(CurrentAttributesTest::Current.user).to eq("jeff")
  end
end
