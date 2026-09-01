require "spec_helper"

RSpec.describe "concurrent sideloading under load" do
  include ConcurrencyHarness

  let(:pool_size) { 4 }

  before do
    allow(Graphiti.config).to receive(:concurrency).and_return(true)
    with_thread_pool(max_threads: pool_size)
  end

  def employee_resource(&definition)
    Class.new(PORO::EmployeeResource) do
      self.model = PORO::Employee
      class_exec(&definition)
    end
  end

  # The request thread resolves the root, so only pool threads are of interest.
  def threads_used(*resource_classes)
    request_thread = Thread.current.object_id
    threads = Concurrent::Array.new
    resource_classes.each do |resource_class|
      allow_any_instance_of(resource_class).to receive(:resolve).and_wrap_original do |original, *args|
        threads << Thread.current.object_id unless Thread.current.object_id == request_thread
        original.call(*args)
      end
    end
    yield
    threads
  end

  def resolve(resource_class, params)
    resource_class.all({page: {size: 100}}.merge(params)).to_a
  end

  describe "a hook that resolves another resource synchronously" do
    before { seed_employees(count: 20, positions_per_employee: 3, departments: 4) }

    let(:one_blocking_assign) do
      employee_resource do
        has_many :positions, resource: PORO::PositionResource do
          assign do |employees, positions|
            PORO::DepartmentResource.all(page: {size: 1}).to_a

            employees.each do |employee|
              employee.positions = positions.select { |position| position.employee_id == employee.id }
            end
          end
        end
      end
    end

    let(:four_blocking_assigns) do
      employee_resource do
        {
          positions: PORO::PositionResource,
          credit_cards: PORO::CreditCardResource,
          visas: PORO::VisaResource,
          gold_visas: PORO::GoldVisaResource
        }.each_pair do |association_name, resource_class|
          has_many association_name, resource: resource_class do
            assign do |_employees, _children|
              PORO::DepartmentResource.all(page: {size: 1}).to_a
            end
          end
        end
      end
    end

    it "does not deadlock when concurrent requests exceed the pool size" do
      resource_class = one_blocking_assign

      run_concurrent_requests(count: pool_size * 2, timeout: 10) do
        resolve(resource_class, include: "positions")
      end
    end

    it "does not deadlock within a single request whose blocking sideloads match the pool size" do
      resource_class = four_blocking_assigns

      run_concurrent_requests(count: 1, timeout: 10) do
        resolve(resource_class, include: "positions,credit_cards,visas,gold_visas")
      end
    end
  end

  describe "a self-referential sideload whose assign lazy-loads per parent" do
    before { seed_employees(count: 30, positions_per_employee: 4, departments: 5) }

    let(:self_referential) do
      employee_resource do
        has_many :related, resource: PORO::EmployeeResource, foreign_key: :id do
          assign do |employees, _related|
            employees.each do |employee|
              PORO::DB.data[:positions].select { |position| position[:employee_id] == employee.id }
            end
          end
        end
      end
    end

    it "keeps each parent's own branches intact" do
      resource_class = self_referential

      results = run_concurrent_requests(count: pool_size * 2, timeout: 20) do
        resolve(resource_class, include: "related.positions,positions.department")
      end

      results.each do |employees|
        expect(employees.length).to eq(30)

        employees.each do |employee|
          expect(employee.positions.length).to eq(4)
          expect(employee.positions.map(&:employee_id).uniq).to eq([employee.id])
        end
      end
    end
  end

  describe "two sideloads at the top level" do
    before { seed_employees(count: 20, positions_per_employee: 3, departments: 4) }

    let(:two_branches) do
      employee_resource do
        has_many :positions, resource: PORO::PositionResource
        has_many :credit_cards, resource: PORO::CreditCardResource
      end
    end

    it "resolves them on separate threads" do
      threads = threads_used(PORO::PositionResource, PORO::CreditCardResource) do
        resolve(two_branches, include: "positions,credit_cards")
      end

      expect(threads.uniq.length).to be > 1
    end
  end

  describe "two sideloads under the same parent" do
    before { seed_employees(count: 20, positions_per_employee: 3, departments: 4) }

    let(:nested_siblings) do
      Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        belongs_to :employee, resource: PORO::EmployeeResource, foreign_key: :employee_id
      end
    end

    let(:parent) do
      sibling_resource = nested_siblings
      employee_resource { has_many :positions, resource: sibling_resource }
    end

    # Siblings a level down are independent queries, so they resolve in parallel.
    it "resolves them on separate threads" do
      threads = threads_used(PORO::DepartmentResource, PORO::EmployeeResource) do
        resolve(parent, include: "positions.department,positions.employee")
      end

      expect(threads.uniq.length).to be > 1
    end

    it "keeps both branches populated under concurrent load" do
      resource_class = parent

      results = run_concurrent_requests(count: pool_size * 2, timeout: 30) do
        resolve(resource_class, include: "positions.department,positions.employee")
      end

      results.each do |employees|
        employees.each do |employee|
          employee.positions.each do |position|
            expect(position.department).not_to be_nil
            expect(position.employee).not_to be_nil
          end
        end
      end
    end
  end

  describe "deep include trees" do
    before { seed_employees(count: 30, positions_per_employee: 4, departments: 5) }

    it "resolves every branch under concurrent load" do
      results = run_concurrent_requests(count: pool_size * 3, timeout: 30) do
        resolve(PORO::EmployeeResource, include: "positions.department.positions")
      end

      results.each do |employees|
        expect(employees.length).to eq(30)

        employees.each do |employee|
          expect(employee.positions.length).to eq(4)

          employee.positions.each do |position|
            expect(position.department).not_to be_nil
            expect(position.department.positions).not_to be_empty
          end
        end
      end
    end
  end
end
