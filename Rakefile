require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "appraisal"

RSpec::Core::RakeTask.new(:spec)

task :cat_gemfile do
  puts File.read("gemfiles/rails_5.gemfile.lock")
end

if !ENV["APPRAISAL_INITIALIZED"] && !ENV["TRAVIS"]
  task :default => :appraisal
else
  task :default => :spec
end
