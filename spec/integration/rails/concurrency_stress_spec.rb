if ENV["APPRAISAL_INITIALIZED"]
  require "rails_spec_helper"

  module StressTest
    DB_POOL_SIZE = Integer(ENV.fetch("DB_POOL_SIZE", 5))
    POOL_THREADS = 4
    DB_PATH = File.expand_path("../../tmp/concurrency_stress.sqlite3", __dir__)
    SIDELOAD_DELAY = Float(ENV.fetch("SIDELOAD_DELAY", 0.02))
  end

  RSpec.describe "concurrent sideloading against ActiveRecord" do
    include ConcurrencyHarness

    before(:all) do
      FileBackedDatabase.connect(StressTest, StressTest::DB_PATH, pool: StressTest::DB_POOL_SIZE)

      StressTest::Base.connection.create_table(:departments, force: true) do |t|
        t.string :name
        t.integer :rank
      end
      StressTest::Base.connection.create_table(:employees, force: true) do |t|
        t.integer :department_id
        t.string :name
      end

      StressTest.const_set(:Department, Class.new(StressTest::Base) {
        self.table_name = "departments"
        has_many :employees, class_name: "StressTest::Employee", foreign_key: :department_id
      })
      StressTest.const_set(:Employee, Class.new(StressTest::Base) {
        self.table_name = "employees"
        belongs_to :department, class_name: "StressTest::Department"
      })

      StressTest.const_set(:EmployeeResource, Class.new(Graphiti::Resource) {
        self.adapter = Graphiti::Adapters::ActiveRecord
        self.model = StressTest::Employee
        self.type = :employees
        attribute :department_id, :integer, only: [:filterable]
        attribute :name, :string
      })

      250.times do |index|
        department = StressTest::Department.create!(name: "department-#{index}", rank: index)
        3.times { |employee| StressTest::Employee.create!(department_id: department.id, name: "employee-#{employee}") }
      end
    end

    after(:all) do
      FileBackedDatabase.disconnect(StressTest, StressTest::DB_PATH,
        %i[EmployeeResource Employee Department])
    end

    before do
      allow(Graphiti.config).to receive(:concurrency).and_return(true)
      with_thread_pool(max_threads: StressTest::POOL_THREADS)
    end

    let(:wide_resource) do
      Class.new(Graphiti::Resource) do
        self.adapter = Graphiti::Adapters::ActiveRecord
        self.model = StressTest::Department
        self.type = :departments
        attribute :name, :string
        attribute :rank, :integer

        has_many :related, resource: StressTest::EmployeeResource, foreign_key: :department_id do
          assign do |parents, _children|
            sleep StressTest::SIDELOAD_DELAY
            parents.each { |parent| parent.employees.to_a }
          end
        end

        10.times do |index|
          has_many :"branch_#{index}", resource: StressTest::EmployeeResource, foreign_key: :department_id do
            assign do |_parents, _children|
              sleep StressTest::SIDELOAD_DELAY
            end
          end
        end
      end
    end

    let(:wide_include) do
      (["related"] + 10.times.map { |index| "branch_#{index}" }).join(",")
    end

    it "resolves a wide index followed by a wide find, concurrently" do
      resource_class = wide_resource

      run_concurrent_requests(count: StressTest::POOL_THREADS * 2, timeout: 90) do
        resource_class.all(page: {size: 250}, fields: {departments: "name,rank"}, sort: "rank").to_a
        resource_class.all(page: {size: 1}, include: wide_include).to_a
      end
    end

    it "leaves the request thread able to query after the pool overflows" do
      resource_class = wide_resource

      run_concurrent_requests(count: StressTest::POOL_THREADS * 3, timeout: 90) do
        resource_class.all(page: {size: 1}, include: wide_include).to_a
      end

      expect(StressTest::Department.count).to eq(250)
    end
  end
end
