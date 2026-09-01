if ENV["APPRAISAL_INITIALIZED"]
  require "rails_spec_helper"

  RSpec.describe "I18n.locale inside concurrent sideloads" do
    include ConcurrencyHarness

    let!(:employee) { Employee.create!(first_name: "Jane") }

    before do
      allow(Graphiti.config).to receive(:concurrency).and_return(true)
      with_thread_pool(max_threads: 2)
    end

    around do |example|
      available = I18n.available_locales
      I18n.available_locales = available | [:de]
      example.run
    ensure
      I18n.locale = I18n.default_locale
      I18n.available_locales = available
    end

    it "resolves a sideload in the locale the request set" do
      observed = nil

      resource_class = Class.new(EmployeeResource) do
        def self.name
          "EmployeeResource"
        end
      end
      resource_class.has_many :probe_positions, resource: PositionResource, foreign_key: :employee_id do
        scope do |_employee_ids|
          observed = {thread: Thread.current.object_id, locale: I18n.locale}
          Position.none
        end
      end

      resource_class.has_many :other_positions, resource: PositionResource, foreign_key: :employee_id do
        scope { |_employee_ids| Position.none }
      end

      I18n.locale = :de
      resource_class.all(filter: {id: employee.id}, include: "probe_positions,other_positions").to_a

      expect(observed[:thread]).to_not eq(Thread.current.object_id)
      expect(observed[:locale]).to eq(:de)
    end
  end
end
