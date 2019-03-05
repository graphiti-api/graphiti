require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "appraisal"

RSpec::Core::RakeTask.new(:spec) do |t|
  if ENV["APPRAISAL_INITIALIZED"]
    t.pattern = "spec/integration/rails"
  end
end

if !ENV["APPRAISAL_INITIALIZED"] && !ENV["TRAVIS"]
  task default: [:spec, :appraisal]
else
  task default: [:spec]
end
