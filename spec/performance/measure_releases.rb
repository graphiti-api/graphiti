require "bundler"
require "io/console"
require "fileutils"
require "open3"
require "tmpdir"
require "digest"
require "etc"
require_relative "scenarios"

# Fills performance_history.tsv. rake -T performance documents the tasks. The
# remaining --promote is called by semantic-release and is not one of them.
module MeasureReleases
  ROOT = File.expand_path("../..", __dir__)
  MEASURE = File.expand_path("measure_release.rb", __dir__)
  HISTORY = File.expand_path("performance_history.tsv", __dir__)
  WORKTREE = File.join(Dir.tmpdir, "graphiti-measure-releases")
  # The first release that boots on ruby 3. Everything older passes a hash where a
  # keyword argument is expected, in graphiti's own code and in the dry-types it pins.
  OLDEST = "v1.2.34"

  COLUMNS = %w[version ruby concurrency scenario phase allocations milliseconds machine tree scenarios].freeze
  PENDING = "pending"

  ALLOCATIONS = COLUMNS.index("allocations")
  MILLISECONDS = COLUMNS.index("milliseconds")
  MACHINE = COLUMNS.index("machine")
  TREE = COLUMNS.index("tree")
  SCENARIOS = COLUMNS.index("scenarios")
  # Minor, because a patch release of ruby does not move allocations
  RUBY = RUBY_VERSION.split(".").first(2).join(".")

  # Ruby 3.4 unbundled these, and tags older than that never named them.
  SHIMS = %w[ostruct bigdecimal mutex_m base64 logger].freeze

  # Skips the test group, whose native extensions (byebug) don't build everywhere the probe runs.
  WITHOUT_TEST = {"BUNDLE_WITHOUT" => "test"}.freeze

  # One line on a tty, nothing at all when the output is piped or captured.
  module Progress
    BAR_WIDTH = 24

    module_function

    # A line wider than the terminal wraps, and the carriage return then only
    # reaches the start of the last fragment, so every draw appends a line.
    def line_width
      @line_width ||= begin
        _, columns = $stderr.winsize
        [columns - 1, 40].max
      rescue
        78
      end
    end

    def start(total, prefix = nil)
      @total = total
      @prefix = prefix
      @done = 0
      @drawing = $stderr.tty?
    end

    def step(label)
      @done += 1
      draw(label)
    end

    # Redraws without advancing, for the checkout and install between measurements.
    def waiting(label)
      draw(label)
    end

    def draw(label)
      return unless @drawing

      filled = BAR_WIDTH * @done / @total
      bar = ("=" * filled).ljust(BAR_WIDTH, ".")
      line = "[#{bar}] #{@done}/#{@total}  #{[@prefix, label].compact.join("  ")}"
      $stderr.print("\r" + line.ljust(line_width)[0, line_width])
    end

    def finish
      return unless @drawing

      $stderr.print("\r" + (" " * line_width) + "\r")
      @drawing = false
    end
  end

  module_function

  # Timings only compare within one box, so the history records which one took them.
  def machine
    @machine ||= begin
      brand = if RUBY_PLATFORM.include?("darwin")
        `sysctl -n machdep.cpu.brand_string 2>/dev/null`
      elsif File.exist?("/proc/cpuinfo")
        File.readlines("/proc/cpuinfo").grep(/model name/).first.to_s.split(":").last
      end
      "#{brand.to_s.strip.tr("\t", " ")}/#{Etc.nprocessors}"
    end
  end

  def timed_elsewhere
    recorded
      .select { |row| row[1] == RUBY && !row[MILLISECONDS].to_s.empty? }
      .map { |row| row[MACHINE] }
      .uniq - [machine, ""]
  end

  def forced?
    ARGV.include?("--force")
  end

  def assert_reference_cpu!
    return if forced?

    others = timed_elsewhere
    return if others.empty?

    abort "the reference CPU for the ruby #{RUBY} timings is #{others.join(", ")} and this is #{machine}. " \
      "Pass --force to make this the reference, or rake performance:read to read the change."
  end

  def stamp(rows)
    rows.map { |row| row.fill("", row.length...MACHINE) + [machine, measured_tree, scenario_fingerprint] }
  end

  # What was measured rather than the file that describes it, so editing a
  # description or a comment does not invalidate a series.
  def scenario_fingerprint
    @scenario_fingerprint ||= begin
      measured = Scenarios::ALL.transform_values { |scenario| scenario.slice(:seed, :params, :latency) }
      Digest::SHA256.hexdigest(measured.inspect)[0, 12]
    end
  end

  def measured_with
    recorded
      .select { |row| row[1] == RUBY && !row[MILLISECONDS].to_s.empty? }
      .map { |row| row[SCENARIOS] }
      .uniq - [scenario_fingerprint, ""]
  end

  def assert_same_scenarios!
    others = measured_with
    return if others.empty? || forced?

    abort "the ruby #{RUBY} rows measured scenarios #{others.join(", ")} and these are #{scenario_fingerprint}. " \
      "The series is not comparable across a change to what is measured, so re-record it with " \
      "rake performance:record ALL=1, or pass --force to record beside them anyway."
  end

  # What the numbers depend on, read off disk rather than out of a commit, so
  # rewriting history does not invalidate a measurement of the same code.
  MEASURED_BY = ["lib", "spec/fixtures/poro.rb", "spec/performance/measure_release.rb",
    "spec/performance/scenarios.rb"].freeze

  # The release bumps this between recording the pending measurement and promoting it.
  NOT_MEASURED_BY = ["lib/graphiti/version.rb"].freeze

  def measured_tree
    @measured_tree ||= begin
      files = `git -C #{ROOT} ls-files #{MEASURED_BY.join(" ")}`.lines.map(&:strip) - NOT_MEASURED_BY
      digest = files.sort.map { |file| "#{file}#{File.read(File.join(ROOT, file))}" }.join
      Digest::SHA256.hexdigest(digest)[0, 12]
    end
  end

  def measurements_per_mode
    Scenarios::ALL.size * Scenarios::PHASES.size
  end

  # ALL=1 replaces every row for this ruby, so there is nothing left for the new
  # numbers to be incomparable with. Only a partial fill lands beside old rows.
  def rebuild(only_missing: false)
    assert_reference_cpu!
    assert_same_scenarios! if only_missing
    @skipped = []
    wanted = only_missing ? tags - recorded.select { |row| row[1] == RUBY }.map(&:first) : tags
    measured = measure_sequence(wanted).flatten(1)
    kept = recorded.reject { |row| row[1] == RUBY && (!only_missing || wanted.include?(row.first)) }
    write(in_release_order(kept + stamp(measured)))
    report_skipped(wanted.length)
  ensure
    remove_worktrees
  end

  # A shortened series and a half-failed sweep otherwise look the same.
  def report_skipped(attempted)
    return puts("measured all #{attempted} releases on ruby #{RUBY}") if skipped.empty?

    puts "measured #{attempted - skipped.length} of #{attempted} releases on ruby #{RUBY}, skipped:"
    skipped.each { |tag, reason| puts format("  %-16s %s", tag, reason) }
  end

  def skipped
    @skipped ||= []
  end

  def skip(tag, reason)
    Progress.finish
    puts "#{tag} skipped, #{reason}"
    skipped << [tag, reason]
    nil
  end

  # Timed in one sitting, so they compare to each other on any machine.
  def compare(count)
    recent = tags.last(count)
    @skipped = []
    Progress.start((recent.length + 1) * MODES.length * measurements_per_mode)
    measured = measure_sequence(recent).flatten(1)
    tree = MODES.flat_map { |mode|
      (measure_in(ROOT, mode) || []).map { |row| ["working tree", RUBY, mode, *row] }
    }
    Progress.finish
    print_totals(measured + tree)
    report_skipped(recent.length) unless skipped.empty?
    puts "\nmeasured here and not recorded, since the history belongs to one machine"
  ensure
    Progress.finish
    remove_worktrees
  end

  def print_totals(rows)
    table = [%w[release concurrency objects ms]]
    rows.group_by { |row| [row.first, row[2]] }.each_pair do |(version, mode), group|
      table << [version, mode, group.sum { |row| row[ALLOCATIONS].to_i }.to_s,
        format("%.1f", group.sum { |row| row[MILLISECONDS].to_f })]
    end

    widths = table.map { |row| row.map(&:length) }.transpose.map(&:max)
    table.each_with_index do |row, index|
      puts row.each_with_index.map { |cell, column|
        (column < 2) ? cell.ljust(widths[column]) : cell.rjust(widths[column])
      }.join("  ").rstrip
      puts "-" * (widths.sum + 8) if index.zero?
    end
  end

  def record(tag)
    abort "unknown tag #{tag}" unless tags.include?(tag)

    assert_reference_cpu!
    assert_same_scenarios!
    rows = measure_release(tag)
    abort "#{tag} could not be measured" if rows.nil? || rows.empty?
    store(tag, stamp(rows))
  ensure
    remove_worktrees
  end

  # The release only renames these, so what ships is what was reviewed.
  def record_pending
    return unless series_exists?

    assert_reference_cpu!
    assert_same_scenarios!
    Progress.start(MODES.length * measurements_per_mode, PENDING)
    rows = MODES.flat_map do |mode|
      measured = measure_in(ROOT, mode)
      measured ? measured.map { |row| [PENDING, RUBY, mode, *row] } : []
    end
    abort "the working tree could not be measured" if rows.empty?
    store(PENDING, stamp(rows))
  ensure
    remove_worktrees
  end

  # A row measured before two more merges describes a tree that no longer exists.
  def promote(version)
    pending = recorded.select { |row| row.first == PENDING }
    # A gap is recoverable, a wrong number labelled as a release is not.
    if pending.empty?
      warn "no pending measurement, so #{version} records none. Fill it in later with rake performance:backfill"
      return
    end

    measured = pending.map { |row| row[TREE] }.uniq
    if measured != [measured_tree] && !forced?
      abort "the pending measurement is of #{measured.join(", ")} and this tree is #{measured_tree}. " \
        "Re-record it with rake performance:pending, or pass --force if the change cannot have moved it."
    end

    # Stamped with what it is being released against, not what it measured, so
    # the file says which tree the number is claimed to describe.
    pending = pending.map { |row| row.dup.tap { |copy| copy[TREE] = measured_tree } }
    warn "released a measurement of #{measured.join(", ")} as #{version}" if measured != [measured_tree]

    write(in_release_order(recorded - pending + pending.map { |row| [version, *row.drop(1)] }))
    puts "released the pending measurement as #{version}"
  end

  # Backfilling a new ruby here would put 31 releases of rows in a release commit.
  def series_exists?
    return true if recorded.any? { |row| row[1] == RUBY }

    warn "no history for ruby #{RUBY}, skipping. run rake performance:record_all to add it"
    false
  end

  def store(version, rows)
    existing = recorded.select { |row| row.first == version && row[1] == RUBY }
    report(version, existing, rows) unless existing.empty?
    write(in_release_order(recorded - existing + rows))
  end

  # A tag's code cannot change, so a moved allocation count means the measurement did.
  def report(tag, existing, rows)
    was = existing.to_h { |row| [row[2..4], row[ALLOCATIONS].to_i] }
    moved = rows.reject { |row| was[row[2..4]] == row[ALLOCATIONS].to_i }

    if moved.empty?
      puts "#{tag} was already recorded on ruby #{RUBY} and measured identically"
      return
    end

    puts "#{tag} was already recorded on ruby #{RUBY} and #{moved.length} of #{rows.length} numbers moved:"
    moved.first(10).each do |_, _, mode, scenario, phase, now, _|
      before = was[[mode, scenario, phase]]
      puts format("  %-46s %-7s %-3s %7s to %-7s", Scenarios.describe(scenario), phase, mode, before || "-", now)
    end
    puts "  and #{moved.length - 10} more" if moved.length > 10
  end

  # On the reference CPU the recorded rows are comparable, so the working tree is
  # measured against them. Anywhere else the releases have to be timed here too.
  def read
    timed_elsewhere.empty? ? current : compare(5)
  end

  def current
    Progress.start(MODES.length * measurements_per_mode)
    rows = MODES.flat_map { |mode| measure_in(ROOT, mode)&.map { |row| ["working tree", RUBY, mode, *row] } || [] }
    Progress.finish
    abort "could not measure the working tree" if rows.empty?

    against = latest_release
    warn "no release measured on ruby #{RUBY}" if against.empty?
    print_table(against, rows)
    puts "  #{plot(rows)}"
  ensure
    Progress.finish
    remove_worktrees
  end

  # Hands over the measurement just taken, so the page does not repeat it.
  def plot(rows)
    require_relative "chart_page"
    "file://#{ChartPage.run(open: false, measured: ChartPage.as_rows(rows))}"
  end

  # Only refreshes a page that already exists, so recording never creates one.
  def replot
    require_relative "chart_page"
    return unless File.exist?(ChartPage::OUTPUT)

    ChartPage.run(open: false)
    puts "#{File.basename(ChartPage::OUTPUT)} refreshed"
  end

  def latest_release
    mine = recorded.select { |row| row[1] == RUBY && row.first != PENDING }
    return [] if mine.empty?

    newest = mine.map(&:first).uniq.last
    mine.select { |row| row.first == newest }
  end

  def print_table(against, rows)
    index = against.to_h { |row| [row[2..4], row] }
    table = [%w[scenario phase concurrency objects was drift ms was]]

    rows.each do |row|
      _, _, mode, scenario, phase, now, milliseconds = row
      was = index[row[2..4]]
      objects_was = was && was[ALLOCATIONS].to_i
      table << [
        Scenarios.describe(scenario), phase, mode,
        now, objects_was || "-", objects_was ? format("%+d", now.to_i - objects_was) : "-",
        format("%.2f", milliseconds), milliseconds_was(was)
      ]
    end

    widths = table.map { |r| r.map { |c| c.to_s.length } }.transpose.map(&:max)
    table.each_with_index do |r, i|
      puts r.each_with_index.map { |cell, c|
        (c < 3) ? cell.to_s.ljust(widths[c]) : cell.to_s.rjust(widths[c])
      }.join("  ").rstrip
      puts "-" * (widths.sum + 10) if i.zero?
    end
    puts "\nagainst #{against.first&.first} on ruby #{RUBY}" unless against.empty?
    puts "\nplotted beside the release history:"
  end

  def milliseconds_was(row)
    return "-" if row.nil? || row[MILLISECONDS].to_s.empty?

    format("%.2f", row[MILLISECONDS].to_f)
  end

  def write(rows)
    content = ([COLUMNS] + rows).map { |row| row.join("\t") }.join("\n") + "\n"
    name = File.basename(HISTORY)
    if File.exist?(HISTORY) && File.read(HISTORY) == content
      puts "#{name} wasn't modified"
      return
    end

    File.write(HISTORY, content)
    puts "#{name} updated"
    replot
  end

  # Rows recorded before timings were kept have no milliseconds cell.
  def recorded
    return [] unless File.exist?(HISTORY)

    File.readlines(HISTORY, chomp: true).drop(1).reject(&:empty?).map do |line|
      line.split("\t").fill("", line.count("\t") + 1...COLUMNS.length)
    end
  end

  def tags
    all = `git -C #{ROOT} tag --list "v*"`.split("\n")
    sorted = all.sort_by { |tag| Gem::Version.new(tag.delete_prefix("v")) }
    sorted.drop_while { |tag| tag != OLDEST }
  rescue ArgumentError
    abort "could not order tags by version"
  end

  # Total, so identical measurements always produce an identical file.
  def in_release_order(rows)
    order = tags
    scenarios = Scenarios::ALL.keys
    rows.sort_by do |row|
      [
        (row.first == PENDING) ? order.length + 1 : order.index(row.first) || order.length,
        ruby_sort_key(row[1]),
        (row[2] == "off") ? 0 : 1,
        scenarios.index(row[3]) || scenarios.length,
        (row[4] == "resolve") ? 0 : 1
      ]
    end
  end

  def ruby_sort_key(version)
    Gem::Version.new(version)
  rescue ArgumentError
    Gem::Version.new("0")
  end

  # Roughly one release in six lands in a slow window and reads high across every
  # scenario at once, which is why a jump is judged on the total rather than a
  # single measurement.
  RETRY_JUMP = 0.10

  def measure_sequence(wanted)
    previous_tag = nil
    previous = nil

    puts "measuring #{wanted.length} releases on ruby #{RUBY}, #{MODES.join(" and ")} concurrency, " \
      "#{measurements_per_mode} measurements each"

    wanted.each_with_index.filter_map do |tag, index|
      counted = "#{index + 1}/#{wanted.length} #{tag}"
      rows = measure_release(tag, counted)
      next if rows.nil?

      jump = jump_from(previous, rows)
      if jump
        puts format("%s totalled %+.0f%% against %s, measuring it again", tag, jump * 100, previous_tag)
        rows = fastest_of(rows, measure_release(tag, "#{counted} again"))
      end
      previous_tag = tag
      previous = rows
      rows
    end
  end

  def jump_from(previous, rows)
    return nil if previous.nil?

    jumps = MODES.filter_map do |mode|
      was = total_milliseconds(previous, mode)
      next unless was.positive?

      (total_milliseconds(rows, mode) - was) / was
    end
    jumps.max&.then { |jump| jump if jump > RETRY_JUMP }
  end

  def total_milliseconds(rows, mode)
    rows.sum { |row| (row[2] == mode) ? row[MILLISECONDS].to_f : 0.0 }
  end

  # Noise only ever reads slow, so the faster pass is the honest one. Allocations
  # are deterministic and identical in both, so the whole row can come from either.
  def fastest_of(rows, again)
    return rows if again.nil?

    best = again.to_h { |row| [row[2..4], row] }
    rows.map do |row|
      other = best[row[2..4]]
      (other && other[MILLISECONDS].to_f < row[MILLISECONDS].to_f) ? other : row
    end
  end

  def measure_release(tag, prefix = tag)
    Progress.start(MODES.length * measurements_per_mode, prefix)
    Progress.waiting("checking out")
    checkout(tag)
    Progress.waiting("bundle install")
    return skip(tag, "bundle install failed") unless bundled?

    measured = MODES.map { |mode| [mode, measure_in(WORKTREE, mode)] }
    empty = measured.find { |_, rows| rows.nil? }
    return skip(tag, failure(empty.first)) if empty

    measured.flat_map { |mode, rows| rows.map { |row| [tag, RUBY, mode, *row] } }
  ensure
    Progress.finish
  end

  # The child's first error line is what says why a release will not boot.
  def failure(mode)
    output, _ = Bundler.with_unbundled_env do
      Open3.capture2e(WITHOUT_TEST, "bundle", "exec", "ruby", MEASURE, mode, chdir: WORKTREE)
    end
    line = output.lines.find { |l| !l.include?("warning:") && !l.start_with?("\t", " ") }
    return "measurement failed" unless line

    line.strip.sub("#{WORKTREE}/", "").sub(/\A\S+:\d+:in '[^']*': /, "")[0, 80]
  end

  def checkout(tag, directory = WORKTREE)
    remove_worktree(directory)
    system("git", "-C", ROOT, "worktree", "add", "--detach", directory, tag, out: File::NULL, err: File::NULL)
    File.open(File.join(directory, "Gemfile"), "a") do |file|
      SHIMS.each { |gem_name| file.puts(%(gem "#{gem_name}")) }
    end
    allow_current_ruby(directory)
  end

  # Tags through v1.2.34 cap required_ruby_version below rubies that can still run them.
  def allow_current_ruby(directory)
    gemspec = File.join(directory, "graphiti.gemspec")
    lines = File.readlines(gemspec).reject { |line| line.include?("required_ruby_version") }
    File.write(gemspec, lines.join)
  end

  def bundled?(directory = WORKTREE)
    Bundler.with_unbundled_env do
      system(WITHOUT_TEST, "bundle", "install", chdir: directory, out: File::NULL, err: File::NULL)
    end
  end

  # The child would otherwise inherit BUNDLE_GEMFILE and resolve against the working tree.
  def measure_in(directory, mode)
    environment = WITHOUT_TEST
    rows = []
    status = nil

    Bundler.with_unbundled_env do
      Open3.popen2e(environment, "bundle", "exec", "ruby", MEASURE, mode, chdir: directory) do |input, output, thread|
        input.close
        output.each_line do |line|
          fields = line.chomp.split("\t")
          case fields.first
          when "START" then Progress.step("concurrency #{mode}  #{fields[2]}  #{Scenarios.describe(fields[1])}")
          when "ROW" then rows << fields.drop(1)
          end
        end
        status = thread.value
      end
    end
    return nil unless status.success?

    rows
  end

  def remove_worktrees
    remove_worktree(WORKTREE)
  end

  def remove_worktree(directory)
    system("git", "-C", ROOT, "worktree", "remove", "--force", directory, out: File::NULL, err: File::NULL)
    FileUtils.rm_rf(directory)
  end

  MODES = %w[off on].freeze
end

if $PROGRAM_NAME == __FILE__
  case ARGV.first
  when "--read" then MeasureReleases.read
  when "--missing" then MeasureReleases.rebuild(only_missing: true)
  when "--all" then MeasureReleases.rebuild
  when "--pending" then MeasureReleases.record_pending
  when "--promote"
    abort "--promote needs a version, e.g. --promote v2.0.0-beta.11" unless ARGV[1]
    MeasureReleases.promote(ARGV[1])
  else MeasureReleases.record(ARGV.first)
  end
end
