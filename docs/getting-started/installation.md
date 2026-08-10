---
title: 'Installation'
---

:::info Requirements
Graphiti 2.0 requires Ruby 3.2+ and ActiveSupport 7.1+. Rails is optional, and 7.1+ if you use it. Coming from 1.x? Remove `graphiti-rails`, `graphiti_spec_helpers` and `graphiti_errors` from your Gemfile: they're part of the main gem now, and the [upgrade guide](/upgrading) covers the rest.
:::

## From Scratch {#from-scratch}

The easiest way to start from scratch is to use the application
template:

```bash
$ rails new blog --api -m https://raw.githubusercontent.com/graphiti-api/graphiti_rails_template/master/all.rb
```

Alternatively, download and point to the template locally:

```bash
$ curl -O https://raw.githubusercontent.com/graphiti-api/graphiti_rails_template/master/all.rb
$ rails new blog --api -m all.rb
```

Run `git diff` to see the changes to a blank Rails app.

## Adding to an Existing App {#adding-to-an-existing-app}

This process is straightforward. You can add Graphiti to an existing
Rails app alongside [JBuilder](https://github.com/rails/jbuilder) or [ActiveModelSerializers](https://github.com/rails-api/active_model_serializers).

Start with gems:

```ruby
# The only strictly-required gem
gem 'graphiti'

# For automatic ActiveRecord pagination
gem 'kaminari'

# Test-specific gems
group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
end

group :test do
  gem 'database_cleaner'
end
```

You'll be up-and-running at this point. Verify with a simple standalone
Resource:

```ruby
# Assuming you already have a Post ActiveRecord Model
class PostResource < Graphiti::Resource
  self.adapter = Graphiti::Adapters::ActiveRecord
  attribute :title, :string
end

PostResource.all.data # => [#<Post>, #<Post>, ...]
```

Now we need to integrate with Rails endpoints (to give us things
like [#context](/concepts/resources#context)):

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Graphiti::Rails::Controller
end
```

And wire-up our error-handling:

```ruby
# app/controllers/application_controller.rb
# When #show action does not find record, return 404
register_exception Graphiti::Errors::RecordNotFound,
  status: 404

rescue_from Exception do |e|
  handle_exception(e)
end
```

That's it for the basics. You may have issues with generators
conflicting with your existing application structure - but you can
always write files manually or [submit an issue](https://github.com/graphiti-api/graphiti/issues).

### Responders {#responders}

Graphiti supports JSONAPI, simple JSON, and XML. You can do this
manually when inheriting from `ActionController::Base`

```ruby
def index
  posts = PostResource.all(params)

  respond_to do |format|
    format.json { render(json: posts) }
    format.jsonapi { render(jsonapi: posts) }
    format.xml { render(xml: posts) }
  end
end
```

But we can inherit from `ActionController::API` while avoiding this
boilerplate with with the [Responders](https://github.com/plataformatec/responders) gem:

```ruby
def index
  posts = PostResource.all(params)
  respond_with(posts)
end
```

To get this functionality:

```ruby
# Gemfile
gem 'responders'

# app/controllers/application_controller.rb
include Graphiti::Rails::Responders
```

> Note: Persistence operations only support JSONAPI format, so you'll
> still use `render jsonapi:` and `render jsonapi_errors:` for those.

### .graphiticfg.yml {#graphiticfg}

The `.graphiticfg.yml` file lives in the root directory of your
application. It holds configuration we need to reuse across a variety of
contexts (primarily generates and rake tasks). If you use our template to create your application, it's created for you.

Primarily this is used to hold your "API namespace":

```yaml
namespace: /my_api/v1
```

If this file doesn't exist you may get unexpected errors - make sure to
create it!

### Testing {#testing}

To add our [Integration Tests](/topics/testing):

```ruby
# Gemfile
group :development, :test do
  gem 'factory_bot_rails'
  gem 'rspec_rails'
  gem 'faker'
end

group :test do
  gem 'database_cleaner'
end
```

Bootstrap RSpec if you haven't already:

```bash
$ bin/rails g rspec:install
```

Then add the Graphiti spec helpers and database cleaning to your `RSpec.configure` block. See [RSpec Setup](/topics/testing#rspec) in the Testing guide for the config to paste in.

### will_paginate {#will-paginate}

By default, we use [Kaminari](https://github.com/kaminari/kaminari) for
ActiveRecord pagination. If you prefer [will_paginate] (or anything
else):

```ruby
# app/resources/application_resource.rb
paginate do |scope, current_page, per_page|
  scope.paginate(page: current_page, per_page: per_page)
end
```

## Without Rails {#without-rails}

You can use Graphiti in any plain `.rb` file. To see this in action,
check out the [Plain Ruby Sample App](https://github.com/graphiti-api/plain_ruby_example).
