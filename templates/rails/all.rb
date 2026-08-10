Thor::Base.shell = Thor::Shell::Color
require "yaml"

def update_config!(attrs)
  config = File.exist?(".graphiticfg.yml") ? YAML.load_file(".graphiticfg.yml") : {}
  config.merge!(attrs)
  File.write(".graphiticfg.yml", config.to_yaml)
end

def prompt(header: nil, description: nil, default: nil)
  say(set_color("\n#{header}", :magenta, :bold)) if header
  say("\n#{description}") if description
  answer = ask(set_color("\n(default: #{default}):", :magenta, :bold))
  answer = default if answer.blank? && default != "nil"
  say(set_color("\nGot it!\n", :white, :bold))
  answer
end

def api_namespace
  @api_namespace ||= begin
    ns = prompt \
      header: "What is your API namespace?",
      description: "This will be used as a route prefix, e.g. if you want the route '/books_api/v1/authors' your namespace would be '/books_api/v1'",
      default: "/api/v1"
    update_config!("namespace" => ns)
    ns
  end
end

welcome = <<-STR
\n
Welcome to the Graphiti generator!
=======================================

This will take care of some boilerplate for you, like adding gem dependencies and rspec helpers.

If you're worried there might be too much magic here, feel free to run 'git diff' at the end to see what happened. You can also learn more at our documentation website, https://graphiti.dev
STR

say(set_color(welcome.rstrip, :cyan, :bold))
api_namespace

gem "graphiti", "~> 2.0.0.beta"
gem "vandal_ui"
gem "kaminari"

gem_group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker" # keep here for seeds.rb
end

gem_group :test do
  gem "database_cleaner-active_record", "~> 2.2"
end

after_bundle do
  rails_command "generate rspec:install"
  run "rm -rf test"

  insert_into_file "spec/rails_helper.rb", after: "RSpec.configure do |config|\n" do
    <<-STR
  config.include FactoryBot::Syntax::Methods
  config.include Graphiti::Rails::TestHelpers

  config.before :each do
    handle_request_exceptions(false)
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  ensure
    DatabaseCleaner.clean
  end

    STR
  end

  run "mkdir -p spec/factories"

  rails_command "generate graphiti:install"
  rake "vandal:install"

  git :init
  git add: "."

  next_steps = <<-STR

You're all set! Next steps:

  Define a model, then generate its Resource, controller, route and specs in one go:

    $ bin/rails generate model post title:string upvotes:integer
    $ bin/rails db:migrate
    $ bin/rails generate graphiti:resource Post title:string upvotes:integer

  Boot the app and try your API:

    $ bin/rails server
    $ curl localhost:3000#{@api_namespace}/posts

  Or explore it visually with Vandal at localhost:3000#{@api_namespace}/vandal

  Full documentation: https://graphiti.dev
STR
  say(set_color(next_steps, :green))
end
