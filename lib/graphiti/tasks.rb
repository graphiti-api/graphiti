namespace :graphiti do
  def session
    @session ||= ActionDispatch::Integration::Session.new(Rails.application)
  end

  def setup_rails!
    Rails.application.eager_load!
    Rails.application.config.cache_classes = true
    Rails.application.config.action_controller.perform_caching = false
  end

  def make_request(path, debug = false)
    if path.split('/').length == 2
      path = "#{ApplicationResource.endpoint_namespace}#{path}"
    end
    if path.include?('?')
      path << '&cache=bust'
    else
      path << '?cache=bust'
    end
    path = "#{path}&debug=true" if debug
    session.get("#{path}")
    JSON.parse(session.response.body)
  end

  desc "Execute request without web server."
  task :request, [:path,:debug] => [:environment] do |_, args|
    setup_rails!
    Graphiti.logger = Graphiti.stdout_logger
    Graphiti::Debugger.preserve = true
    require 'pp'
    path, debug = args[:path], args[:debug]
    puts "Graphiti Request: #{path}"
    json = make_request(path, debug)
    pp json
    Graphiti::Debugger.flush if debug
  end

  desc "Execute benchmark without web server."
  task :benchmark, [:path,:requests] => [:environment] do |_, args|
    setup_rails!
    took = Benchmark.ms do
      args[:requests].to_i.times do
        make_request(args[:path])
      end
    end
    puts "Took: #{(took / args[:requests].to_f).round(2)}ms"
  end
end
