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

# Allocations mean the same anywhere and timings do not, so the history has a
# reference CPU, named on every row, and recording timings refuses to mix them.
namespace :performance do
  # Shelling out keeps a failure to the script's own message, with no rake backtrace on top.
  def measure(*arguments)
    exit(1) unless system("bundle", "exec", "ruby", "spec/performance/measure_releases.rb", *arguments)
  end

  desc "Read a change: measure the working tree, print the comparison and plot it"
  task :read do
    measure("--read")
  end

  desc "Open the recorded history as a chart. Any machine, measures nothing"
  task :chart do
    exit(1) unless system("bundle", "exec", "ruby", "spec/performance/chart_page.rb", "--no-current")
  end

  desc "Fill in the history. Missing releases by default, TAG=v2.0.0-beta.9 for one, ALL=1 for every. Reference CPU"
  task :record do
    measure(*(if ENV["TAG"]
                [ENV["TAG"]]
              else
                ENV["ALL"] ? ["--all"] : ["--missing"]
              end))
  end

  desc "Measure the working tree for the release to name, and commit it. Reference CPU"
  task :pending do
    measure("--pending")
  end
end

if ENV["APPRAISAL_INITIALIZED"]
  task default: [:spec]
else
  task default: [:standard, :spec, :appraisal]
end
