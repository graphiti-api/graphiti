module ConcurrencyHarness
  class Timeout < StandardError; end

  def with_thread_pool(max_threads:, max_queue: nil)
    max_queue ||= max_threads * 4
    stub_const(
      "Graphiti::Scope::GLOBAL_THREAD_POOL_EXECUTOR",
      Concurrent::Promises.delay do
        Concurrent::ThreadPoolExecutor.new(
          min_threads: 0,
          max_threads: max_threads,
          max_queue: max_queue,
          fallback_policy: :caller_runs
        )
      end
    )
  end

  def run_concurrent_requests(count:, timeout: 20, context: {})
    threads = Array.new(count) { |index|
      Thread.new do
        Thread.current.report_on_exception = false
        Graphiti.with_context(context, :index) { yield index }
      end
    }

    deadline = monotonic_now + timeout
    sleep 0.05 while threads.any?(&:alive?) && monotonic_now < deadline

    stalled = threads.select(&:alive?)
    unless stalled.empty?
      dump = all_thread_backtraces
      threads.each(&:kill)
      raise Timeout, "#{stalled.size}/#{count} request threads still running after #{timeout}s\n\n#{dump}"
    end

    threads.map(&:value)
  end

  def all_thread_backtraces
    Thread.list.map { |thread|
      frames = (thread.backtrace || ["<no backtrace>"]).first(30)
      "#<Thread:0x#{thread.object_id.to_s(16)} #{thread.status}>\n  #{frames.join("\n  ")}"
    }.join("\n\n")
  end

  def live_slots
    GC.start(full_mark: true, immediate_sweep: true)
    GC.stat[:heap_live_slots]
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def seed_employees(count:, positions_per_employee:, departments:)
    department_ids = Array.new(departments) { |index|
      PORO::Department.create(name: "department-#{index}").id
    }

    Array.new(count) { |employee_index|
      employee = PORO::Employee.create(
        first_name: "first-#{employee_index}",
        last_name: "last-#{employee_index}",
        age: 20 + (employee_index % 40)
      )

      positions_per_employee.times do |position_index|
        PORO::Position.create(
          employee_id: employee.id,
          title: "title-#{position_index}",
          rank: position_index,
          department_id: department_ids[position_index % department_ids.length]
        )
      end

      employee
    }
  end
end
