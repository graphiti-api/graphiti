# Runs inside a checkout of one released tag, so it can only use the public API.
$LOAD_PATH.unshift(File.expand_path("lib", Dir.pwd))
# Old versions use these without requiring them, which was fine when they were
# default gems and loaded for free.
require "ostruct"
require "bigdecimal"
require "active_model"
require "graphiti"
Graphiti::Resource.autolink = false if Graphiti::Resource.respond_to?(:autolink=)
require File.expand_path("spec/fixtures/poro.rb", Dir.pwd)
Graphiti.setup!
require File.expand_path("scenarios.rb", __dir__)

module Scenarios
  SCENARIOS = ::Scenarios::ALL

  PHASES = {
    "resolve" => ->(proxy) { proxy.to_a },
    "render" => ->(proxy) { proxy.to_jsonapi }
  }.freeze

  MODES = %w[off on].freeze

  module_function

  def seed(employees:, positions_per_employee: 0, departments: 1)
    department_ids = Array.new(departments) { |index| PORO::Department.create(name: "d#{index}").id }

    employees.times do |employee_index|
      employee = PORO::Employee.create(first_name: "f#{employee_index}", age: 30)
      positions_per_employee.times do |position_index|
        PORO::Position.create(
          employee_id: employee.id,
          title: "t#{position_index}",
          department_id: department_ids[position_index % department_ids.length]
        )
      end
    end
  end

  def allocations
    GC.start(full_mark: true, immediate_sweep: true)
    GC.disable
    before = GC.stat[:total_allocated_objects]
    yield
    GC.stat[:total_allocated_objects] - before
  ensure
    GC.enable
  end

  # Old versions mutate the params they are given, and two warm-up passes settle memoized state.
  def measure(scenario, phase, context)
    call = PHASES.fetch(phase)

    PORO::DB.clear
    seed(**scenario[:seed])

    passes = 3.times.map { Marshal.load(Marshal.dump(scenario[:params])) }
    measured = passes.pop

    Graphiti.with_context(context, :index) do
      passes.each { |params| call.call(PORO::EmployeeResource.all(params)) }
      allocations { call.call(PORO::EmployeeResource.all(measured)) }
    end
  end

  def each_measurement(context)
    SCENARIOS.each_pair do |id, scenario|
      PHASES.each_key do |phase|
        yield id, phase, measure(scenario, phase, context)
      end
    end
  end
end

Graphiti.config.concurrency = (ARGV[0] == "on")
CONTEXT = Struct.new(:current_user).new("none")

Scenarios.each_measurement(CONTEXT) do |scenario, phase, count|
  puts "ROW\t#{scenario}\t#{phase}\t#{count}"
end
