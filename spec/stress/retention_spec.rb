require "spec_helper"

RSpec.describe "object retention across concurrent rounds" do
  include ConcurrencyHarness

  let(:pool_size) { 4 }

  before do
    allow(Graphiti.config).to receive(:concurrency).and_return(true)
    with_thread_pool(max_threads: pool_size)
    seed_employees(count: 25, positions_per_employee: 4, departments: 5)
  end

  it "does not accumulate live objects" do
    rounds = 10
    warmup_rounds = 2
    samples = []

    rounds.times do
      run_concurrent_requests(count: pool_size, timeout: 30) do
        PORO::EmployeeResource.all(page: {size: 100}, include: "positions.department").to_a
      end

      samples << live_slots
    end

    settled = samples[warmup_rounds]
    growth = samples.last - settled

    expect(growth).to be < settled * 0.1,
      "live objects grew #{growth} slots (#{(growth * 100.0 / settled).round(1)}%) " \
      "over #{rounds - warmup_rounds} rounds: #{samples.inspect}"
  end
end
