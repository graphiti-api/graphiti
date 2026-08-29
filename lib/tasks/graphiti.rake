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

  namespace :schema do
    desc "Write the schema file. Refuses backwards-incompatible changes unless FORCE_SCHEMA=true. Takes an optional path, defaulting to Graphiti.config.schema_path."
    task :generate, [:path] => [:environment] do |_, args|
      check = Graphiti::Schema.check(path: helpers.schema_path(args[:path]))
      abort check.message unless check.compatible? || ENV["FORCE_SCHEMA"] == "true"

      puts "Schema written: #{check.write!}"
    end

    desc "Fail unless the committed schema file exists, is up to date, and is backwards-compatible. Takes an optional path, defaulting to Graphiti.config.schema_path."
    task :check, [:path] => [:environment] do |_, args|
      check = Graphiti::Schema.check(path: helpers.schema_path(args[:path]))
      abort check.message unless check.ok?

      puts check.message
    end
  end

  desc "Audit every relationship: what will raise, what loads to render ids, which render no ids, and which checks passed."
  task audit: [:environment] do
    helpers.setup_rails!
    rows = Graphiti::Audit.run
    puts Graphiti::Audit::Report.new(rows)

    if (advisory = helpers.connection_pool_advisory)
      puts advisory
    end

    exit 1 if rows.any?(&:error?)
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
