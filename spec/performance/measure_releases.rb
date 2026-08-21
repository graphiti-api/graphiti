require "bundler"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "scenarios"

# Fills performance_history.tsv, which holds one series per ruby.
#
#   ruby spec/performance/measure_releases.rb --all          re-record this ruby's series
#   ruby spec/performance/measure_releases.rb v2.0.0-beta.9  record one release
#   ruby spec/performance/measure_releases.rb --pending v2.0.0-beta.9  record the working tree as that version
#   ruby spec/performance/measure_releases.rb                the working tree, printed only
module MeasureReleases
  ROOT = File.expand_path("../..", __dir__)
  MEASURE = File.expand_path("measure_release.rb", __dir__)
  HISTORY = File.expand_path("performance_history.tsv", __dir__)
  WORKTREE = File.join(Dir.tmpdir, "graphiti-measure-releases")
  # The first stable 1.0 release. The 0.x era predates the resource API the probe drives.
  OLDEST = "v1.0.1"

  COLUMNS = %w[version ruby concurrency scenario phase allocations].freeze
  # Minor, because CI pins rubies as "3.4" and patches generally don't move allocations
  RUBY = RUBY_VERSION.split(".").first(2).join(".")

  # Ruby 3.4 unbundled these, and tags older than that never named them.
  SHIMS = %w[ostruct bigdecimal mutex_m base64 logger].freeze

  # Skips the test group, whose native extensions (byebug) don't build everywhere the probe runs.
  WITHOUT_TEST = {"BUNDLE_WITHOUT" => "test"}.freeze

  module_function

  # Leaves the other rubies' rows alone.
  def rebuild
    @skipped = []
    measured = tags.filter_map { |tag| measure_release(tag) }.flatten(1)
    write(in_release_order(recorded.reject { |row| row[1] == RUBY } + measured))
    report_skipped(tags.length)
  ensure
    remove_worktree
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
    skipped << [tag, reason]
    nil
  end

  def record(tag)
    abort "unknown tag #{tag}" unless tags.include?(tag)

    rows = measure_release(tag)
    abort "#{tag} could not be measured" if rows.nil? || rows.empty?
    store(tag, rows)
  ensure
    remove_worktree
  end

  # During a release the working tree is the version being tagged, and the tag does not exist yet.
  def record_pending(version)
    return unless series_exists?

    rows = MODES.flat_map do |mode|
      measured = measure_in(ROOT, mode)
      measured ? measured.map { |row| [version, RUBY, mode, *row] } : []
    end
    abort "#{version} could not be measured" if rows.empty?
    store(version, rows)
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

  # A tag's code cannot change, so a moved number means the measurement did.
  def report(tag, existing, rows)
    was = existing.to_h { |row| [row[2..4], row[5].to_i] }
    moved = rows.reject { |row| was[row[2..4]] == row[5].to_i }

    if moved.empty?
      puts "#{tag} was already recorded on ruby #{RUBY} and measured identically"
      return
    end

    puts "#{tag} was already recorded on ruby #{RUBY} and #{moved.length} of #{rows.length} numbers moved:"
    moved.first(10).each do |_, _, mode, scenario, phase, now|
      before = was[[mode, scenario, phase]]
      puts format("  %-46s %-7s %-3s %7s to %-7s", Scenarios.describe(scenario), phase, mode, before || "-", now)
    end
    puts "  and #{moved.length - 10} more" if moved.length > 10
  end

  def current
    rows = MODES.flat_map { |mode| measure_in(ROOT, mode)&.map { |row| ["working tree", RUBY, mode, *row] } || [] }
    abort "could not measure the working tree" if rows.empty?

    against = latest_release
    warn "no release measured on ruby #{RUBY}" if against.empty?
    print_table(against, rows)
    puts "  #{plot(rows)}"
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

    ChartPage.run(open: false, current: false)
    puts "#{File.basename(ChartPage::OUTPUT)} refreshed without the working tree"
  end

  def latest_release
    mine = recorded.select { |row| row[1] == RUBY }
    return [] if mine.empty?

    newest = mine.map(&:first).uniq.last
    mine.select { |row| row.first == newest }
  end

  def print_table(against, rows)
    index = against.to_h { |row| [row[2..4], row[5].to_i] }
    header = %w[scenario phase concurrency now was drift]
    table = [header]

    rows.each do |row|
      _, _, mode, scenario, phase, now = row
      was = index[row[2..4]]
      table << [Scenarios.describe(scenario), phase, mode, now, was || "-", was ? format("%+d", now.to_i - was) : "-"]
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

  def recorded
    return [] unless File.exist?(HISTORY)

    File.readlines(HISTORY, chomp: true).drop(1).reject(&:empty?).map { |line| line.split("\t") }
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
        order.index(row.first) || order.length,
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

  def measure_release(tag)
    checkout(tag)
    return skip(tag, "bundle install failed") unless bundled?

    measured = MODES.map { |mode| [mode, measure_in(WORKTREE, mode)] }
    empty = measured.find { |_, rows| rows.nil? }
    return skip(tag, failure(empty.first)) if empty

    measured.flat_map { |mode, rows| rows.map { |row| [tag, RUBY, mode, *row] } }
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

  def checkout(tag)
    remove_worktree
    system("git", "-C", ROOT, "worktree", "add", "--detach", WORKTREE, tag, out: File::NULL, err: File::NULL)
    File.open(File.join(WORKTREE, "Gemfile"), "a") do |file|
      SHIMS.each { |gem_name| file.puts(%(gem "#{gem_name}")) }
    end
    allow_current_ruby
  end

  # Tags through v1.2.34 cap required_ruby_version below rubies that can still run them.
  def allow_current_ruby
    gemspec = File.join(WORKTREE, "graphiti.gemspec")
    lines = File.readlines(gemspec).reject { |line| line.include?("required_ruby_version") }
    File.write(gemspec, lines.join)
  end

  def bundled?
    Bundler.with_unbundled_env do
      system(WITHOUT_TEST, "bundle", "install", chdir: WORKTREE, out: File::NULL, err: File::NULL)
    end
  end

  # The child would otherwise inherit BUNDLE_GEMFILE and resolve against the working tree.
  def measure_in(directory, mode)
    output, status = Bundler.with_unbundled_env do
      Open3.capture2e(WITHOUT_TEST, "bundle", "exec", "ruby", MEASURE, mode, chdir: directory)
    end
    return nil unless status.success?

    output.lines.grep(/\AROW\t/).map { |line| line.chomp.split("\t").drop(1) }
  end

  def remove_worktree
    system("git", "-C", ROOT, "worktree", "remove", "--force", WORKTREE, out: File::NULL, err: File::NULL)
    FileUtils.rm_rf(WORKTREE)
  end

  MODES = %w[off on].freeze
end

if $PROGRAM_NAME == __FILE__
  case ARGV.first
  when nil then MeasureReleases.current
  when "--all" then MeasureReleases.rebuild
  when "--pending"
    abort "--pending needs a version, e.g. --pending v2.0.0-beta.9" unless ARGV[1]
    MeasureReleases.record_pending(ARGV[1])
  else MeasureReleases.record(ARGV.first)
  end
end
