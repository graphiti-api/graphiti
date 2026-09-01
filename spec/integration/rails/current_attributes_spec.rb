if ENV["APPRAISAL_INITIALIZED"]
  require "rails_spec_helper"

  module RailsCurrentAttributesTest
    class Current < ActiveSupport::CurrentAttributes
      attribute :user
    end
  end

  RSpec.describe "CurrentAttributes inside concurrent sideloads" do
    include ConcurrencyHarness

    let!(:employee) { Employee.create!(first_name: "Jane") }

    before do
      allow(Graphiti.config).to receive(:concurrency).and_return(true)
      with_thread_pool(max_threads: 2)
    end

    after { RailsCurrentAttributesTest::Current.reset }

    it "survives the executor handing the pool thread a fresh Current" do
      observed = nil

      resource_class = Class.new(EmployeeResource) do
        def self.name
          "EmployeeResource"
        end
      end
      # Position.none, because the pool thread's connection does not see the
      # in-memory test schema. The scope block still runs where a real one would.
      resource_class.has_many :probe_positions, resource: PositionResource, foreign_key: :employee_id do
        scope do |_employee_ids|
          observed = {thread: Thread.current.object_id, user: RailsCurrentAttributesTest::Current.user}
          Position.none
        end
      end

      # A second sideload, since one on its own resolves inline and never reaches the pool.
      resource_class.has_many :other_positions, resource: PositionResource, foreign_key: :employee_id do
        scope { |_employee_ids| Position.none }
      end

      RailsCurrentAttributesTest::Current.user = "jeff"
      resource_class.all(filter: {id: employee.id}, include: "probe_positions,other_positions").to_a

      expect(observed[:thread]).to_not eq(Thread.current.object_id)
      expect(observed[:user]).to eq("jeff")
    end
  end
end
