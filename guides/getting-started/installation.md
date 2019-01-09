---
layout: page
---

<div markdown="1" class="toc col-md-3">
Installation
==========

* 1 [From Scratch](#from-scratch)
* 2 [Adding to an Existing App](#adding-to-an-existing-app)
  * [Responders](#responders)
  * [Testing](#testing)
  * [will_paginate](#willpaginate)
* 3 [Without Rails](#without-rails)

</div>

<div markdown="1" class="col-md-8">
## 1 From Scratch

The easiest way to start from scratch is to use the application
template:

{% highlight bash %}
$ rails new blog --api -m https://raw.githubusercontent.com/graphiti-api/graphiti_rails_template/master/all.rb
{% endhighlight %}

Alternatively, download and point to the template locally:

{% highlight bash %}
$ curl -O https://raw.githubusercontent.com/graphiti-api/graphiti_rails_template/master/all.rb
$ rails new blog --api -m all.rb
{% endhighlight %}

Run `git diff` to see the changes to a blank Rails app.

## 2 Adding to an Existing App

This process is straightforward; you can add Graphiti to an existing
Rails app alongside [JBuilder](https://github.com/rails/jbuilder) or [ActiveModelSerializers](https://github.com/rails-api/active_model_serializers).

Start with gems:

{% highlight ruby %}
# The only strictly-required gem
gem 'graphiti'

# For automatic ActiveRecord pagination
gem 'kaminari'

# Test-specific gems
group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'graphiti_spec_helpers'
end

group :test do
  gem 'database_cleaner'
end
{% endhighlight %}

You'll be up-and-running at this point. Verify with a simple standalone
Resource:

{% highlight ruby %}
# Assuming you already have a Post ActiveRecord Model
class PostResource < Graphiti::Resource
  self.adapter = Graphiti::Adapters::ActiveRecord
  attribute :title, :string
end

PostResource.all.data # => [#<Post>, #<Post>, ...]
{% endhighlight %}

Now we just need to integrate with Rails endpoints (to give us things
like [#context]({{site.github.url}}/guides/concepts/resources#context)):

{% highlight ruby %}
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Graphiti::Rails
end
{% endhighlight %}

And wire-up our error-handling:

{% highlight ruby %}
# app/controllers/application_controller.rb
# When #show action does not find record, return 404
register_exception Graphiti::Errors::RecordNotFound,
  status: 404

rescue_from Exception do |e|
  handle_exception(e)
end
{% endhighlight %}

That's it for the basics. You may have issues with generators
conflicting with your existing application structure - but you can
always write files manually or [submit an issue](https://github.com/graphiti-api/graphiti/issues).

### 2.1 Responders

Graphiti supports JSONAPI, simple JSON, and XML. You can do this
manually when inheriting from `ActionController::Base`

{% highlight ruby %}
def index
  posts = PostResource.all(params)

  respond_to do |format|
    format.json { render(json: posts.to_json) }
    format.jsonapi { render(jsonapi: posts.to_jsonapi) }
    format.xml { render(xml: posts.to_xml) }
  end
end
{% endhighlight %}

But we can inherit from `ActionController::API` while avoiding this
boilerplate with with the [Responders](https://github.com/plataformatec/responders) gem:

{% highlight ruby %}
def index
  posts = PostResource.all(params)
  respond_with(posts)
end
{% endhighlight %}

To get this functionality:

{% highlight ruby %}
# Gemfile
gem 'responders'

# app/controllers/application_controller.rb
include Graphiti::Responders
{% endhighlight %}

> Note: Persistence operations only support JSONAPI format, so you'll
> still use `render jsonapi:` and `render jsonapi_errors:` for those.

### 2.2 Testing

To add our [Integration Tests]({{site.github.url}}/guides/concepts/testing):

{% highlight ruby %}
# Gemfile
group :development, :test do
  gem 'graphiti_spec_helpers'
  gem 'factory_bot_rails'
  gem 'rspec_rails'
  gem 'faker'
end

group :test do
  gem 'database_cleaner'
end
{% endhighlight %}

Bootstrap RSpec if you haven't already:

{% highlight bash %}
$ bin/rails g rspec:install
{% endhighlight %}

Add some RSpec configuration:

{% highlight ruby %}
require 'graphiti_spec_helpers/rspec'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include GraphitiSpecHelpers::RSpec
  config.include GraphitiSpecHelpers::Sugar

  # Raise errors during tests by default
  config.before :each do
    GraphitiErrors.disable!
  end

  # Clean your DB between test runs
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    begin
      DatabaseCleaner.cleaning do
        example.run
      end
    ensure
      DatabaseCleaner.clean
    end
  end
end
{% endhighlight %}

### 2.3 will_paginate

By default, we use [Kaminari](https://github.com/kaminari/kaminari) for
ActiveRecord pagination. If you prefer [will_paginate] (or anything
else):

{% highlight ruby %}
# app/resources/application_resource.rb
paginate do |scope, current_page, per_page|
  scope.paginate(page: current_page, per_page: per_page)
end
{% endhighlight %}

## Without Rails

You can use Graphiti in any plain `.rb` file. To see this in action,
check out the [Plain Ruby Sample App](https://github.com/graphiti-api/plain_ruby_example).

<br />
<br />
