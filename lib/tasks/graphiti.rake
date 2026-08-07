require "graphiti/rails/rake_helpers"

namespace :graphiti do
  helpers = Graphiti::Rails::RakeHelpers

  desc "Execute request without web server."
  task :request, [:path, :debug] => [:environment] do |_, args|
    helpers.setup_rails!
    Graphiti.logger = Graphiti.stdout_logger
    Graphiti::Debugger.preserve = true
    require "pp"
    path, debug = args[:path], args[:debug]
    puts "Graphiti Request: #{path}"
    json = helpers.make_request(path, debug)
    pp json
    Graphiti::Debugger.flush if debug
  end

  desc "Execute benchmark without web server."
  task :benchmark, [:path, :requests] => [:environment] do |_, args|
    helpers.setup_rails!
    took = Benchmark.ms {
      args[:requests].to_i.times do
        helpers.make_request(args[:path])
      end
    }
    puts "Took: #{(took / args[:requests].to_f).round(2)}ms"
  end
end
