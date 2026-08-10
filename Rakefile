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

if ENV["APPRAISAL_INITIALIZED"]
  task default: [:spec]
else
  task default: [:standard, :spec, :appraisal]
end
