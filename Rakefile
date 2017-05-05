require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "appraisal"

RSpec::Core::RakeTask.new(:spec)

if !ENV["APPRAISAL_INITIALIZED"] && !ENV["TRAVIS"]
  task :default => :appraisal
else
  task :default => :spec
end
