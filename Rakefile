require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "appraisal"
# Standard is silent on success; show the inspected-files summary.
ENV["STANDARDOPTS"] ||= "--format progress"
require "standard/rake"

RSpec::Core::RakeTask.new(:spec) do |t|
  if ENV["APPRAISAL_INITIALIZED"]
    t.pattern = "spec/integration/rails"
  end
end

namespace :performance do
  # Shelling out keeps a failure to the script's own message, with no rake backtrace on top.
  def measure(*arguments)
    exit(1) unless system("bundle", "exec", "ruby", "spec/performance/measure_releases.rb", *arguments)
  end

  desc "Compare the working tree to the last release, and plot it"
  task :current do
    measure
  end

  desc "Plot the release history plus the working tree to tmp/performance.html and open it"
  task :page do
    exit(1) unless system("bundle", "exec", "ruby", "spec/performance/chart_page.rb")
  end

  desc "Measure one release and record it (TAG=v2.0.0-beta.9)"
  task :record do
    tag = ENV["TAG"] or abort "pass the release to record, e.g. rake performance:record TAG=v2.0.0-beta.9"
    measure(tag)
  end

  desc "Re-record every release for this ruby, replacing its rows"
  task :record_all do
    measure("--all")
  end
end

if ENV["APPRAISAL_INITIALIZED"]
  task default: [:spec]
else
  task default: [:standard, :spec, :appraisal]
end
