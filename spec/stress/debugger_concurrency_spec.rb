require "spec_helper"

RSpec.describe "debugger under concurrent requests" do
  include ConcurrencyHarness

  let(:pool_size) { 4 }

  before do
    allow(Graphiti.config).to receive(:concurrency).and_return(true)
    with_thread_pool(max_threads: pool_size)
    seed_employees(count: 10, positions_per_employee: 3, departments: 3)
    @original_logger = Graphiti.logger
    Graphiti.logger = Logger.new(IO::NULL)
    Graphiti::Debugger.enabled = true
  end

  after do
    Graphiti::Debugger.enabled = false
    Graphiti::Debugger.chunks = []
    Graphiti.logger = @original_logger
  end

  def capture_flushes
    flushes = Concurrent::Array.new
    subscriber = ActiveSupport::Notifications.subscribe("flush_debug.graphiti") do |*, payload|
      flushes << {chunk_count: payload[:chunks].size, array_id: payload[:chunks].object_id}
    end
    yield
    flushes.to_a
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def debugged_request
    Graphiti::Debugger.debug do
      PORO::EmployeeResource.all(page: {size: 100}, include: "positions.department").to_a
    end
  end

  it "flushes each request's own chunks when requests overlap" do
    alone = capture_flushes {
      Graphiti.with_context({}, :index) { debugged_request }
    }.first

    overlapping = capture_flushes {
      run_concurrent_requests(count: pool_size * 2, timeout: 30) { debugged_request }
    }

    expect(overlapping.map { |flush| flush[:array_id] }.uniq.size).to eq(overlapping.size)
    expect(overlapping.map { |flush| flush[:chunk_count] }.uniq).to eq([alone[:chunk_count]])
  end
end
