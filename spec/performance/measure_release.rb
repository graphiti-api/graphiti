# Runs inside a checkout of one released tag, so it can only use the public API.
$LOAD_PATH.unshift(File.expand_path("lib", Dir.pwd))
# Old versions use these without requiring them, which was fine when they were
# default gems and loaded for free.
require "ostruct"
require "bigdecimal"
require "active_model"
require "graphiti"
if Graphiti::Resource.respond_to?(:relationship_links=)
  Graphiti::Resource.relationship_links = false
elsif Graphiti::Resource.respond_to?(:autolink=)
  Graphiti::Resource.autolink = false
end
require File.expand_path("spec/fixtures/poro.rb", Dir.pwd)
Graphiti.setup!

require File.expand_path("scenarios.rb", __dir__)

LATENCY_OVERRIDE = ENV["PERF_LATENCY"] && Float(ENV["PERF_LATENCY"])

module QueryLatency
  class << self
    attr_accessor :seconds
  end
  self.seconds = 0.0

  def self.for(scenario)
    LATENCY_OVERRIDE || scenario[:latency].to_f
  end
end

# Left unprepended when nothing waits, so a scenario measuring graphiti's own work does not pay for the wrapper.
if Scenarios::ALL.each_value.any? { |scenario| QueryLatency.for(scenario) > 0 } && defined?(PORO::Adapter)
  PORO::Adapter.prepend(Module.new do
    def resolve(scope)
      sleep(QueryLatency.seconds) if QueryLatency.seconds > 0
      super
    end
  end)
end

module Scenarios
  SCENARIOS = ::Scenarios::ALL

  PHASE_CALLS = {
    "resolve" => ->(proxy) { proxy.to_a },
    "render" => ->(proxy) { proxy.to_jsonapi }
  }.freeze

  MODES = %w[off on].freeze
  # A budget rather than a pass count, so cheap and expensive scenarios both get enough passes.
  TIMING_BUDGET_SECONDS = 1.0
  MINIMUM_TIMED_PASSES = 5

  module_function

  def seed(employees:, positions_per_employee: 0, departments: 1, credit_cards_per_employee: 0)
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
      credit_cards_per_employee.times do |card_index|
        PORO::Visa.create(employee_id: employee.id, number: card_index)
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

  # Old versions mutate the params they are given, and warm-up passes settle memoized state.
  def measure(scenario, phase, context)
    call = PHASE_CALLS.fetch(phase)

    QueryLatency.seconds = QueryLatency.for(scenario)
    PORO::DB.clear
    seed(**scenario[:seed])

    fresh_params = -> { Marshal.load(Marshal.dump(scenario[:params])) }
    run = -> { call.call(PORO::EmployeeResource.all(fresh_params.call)) }

    Graphiti.with_context(context, :index) do
      2.times { run.call }
      objects = allocations(&run)
      [objects, (fastest(&run) * 1000).round(3)]
    end
  end

  def fastest
    fastest = Float::INFINITY
    passes = 0
    deadline = now + TIMING_BUDGET_SECONDS
    while passes < MINIMUM_TIMED_PASSES || now < deadline
      started = now
      yield
      fastest = [fastest, now - started].min
      passes += 1
    end
    fastest
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def each_measurement(context)
    SCENARIOS.each_pair do |id, scenario|
      ::Scenarios::PHASES.each do |phase|
        puts "START\t#{id}\t#{phase}"
        yield id, phase, *measure(scenario, phase, context)
      end
    end
  end
end

$stdout.sync = true
Graphiti.config.concurrency = (ARGV[0] == "on")
CONTEXT = Struct.new(:current_user).new("none")

Scenarios.each_measurement(CONTEXT) do |scenario, phase, count, milliseconds|
  puts "ROW\t#{scenario}\t#{phase}\t#{count}\t#{milliseconds}"
end
