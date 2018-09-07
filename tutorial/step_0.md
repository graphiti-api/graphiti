---
layout: page
---

Tutorial
==========

### Step 0: Bootstrapping

Let's start by creating a new Rails project. We'll use the `-m` option to install from a template, which will add a few gems and apply some setup boilerplate:

{% highlight bash %}
$ rails new employee_directory --api -m https://raw.githubusercontent.com/graphiti-api/graphiti_rails_template/master/all.rb

$ cd employee_directory
{% endhighlight %}

> Note: if a network issue prevents you from pointing to this URL directly, you can download the file and and run this command as `-m /path/to/all.rb`

Feel free to run `git diff` to see what the generator did, otherwise commit the result.

#### Digging Deeper

You'll see some boilerplate in `config/routes.rb`:

{% highlight ruby %}
scope path: ApplicationResource.endpoint_namespace, defaults: { format: :jsonapi } do
  # your routes go here
end
{% endhighlight %}

This tells Rails that our API routes will be be prefixed - `/api/v1` by default. It also
says that if no extension is in the URL (`.json`, `.xml`, etc), default
to the [JSONAPI Specification](http://jsonapi.org).

Let's look at the above `ApplicationResource`:

{% highlight ruby %}
class ApplicationResource < Graphiti::Resource
  self.abstract_class = true

  # We'll be using ActiveRecord
  self.adapter = Graphiti::Adapters::ActiveRecord

  # Links are generated from base_url + endpoint_namespace
  self.base_url = Rails.application.routes.default_url_options[:host]
  self.endpoint_namespace = '/api/v1'
end
{% endhighlight %}

This should be pretty self-explanatory except for

{% highlight ruby %}
self.base_url = Rails.application.routes.default_url_options[:host]
{% endhighlight %}

This is configured in `config/application.rb`:

{% highlight ruby %}
module EmployeeDirectory
  class Application < Rails::Application
    routes.default_url_options[:host] = ENV.fetch('HOST', 'http://localhost:3000')
    # ... code ...
  end
end
{% endhighlight %}

<!-- TODO: Link to Link overview/documentation -->

When deriving and validating Links, we'll use the `HOST` variable if
present, falling back to the Rails development default of
`http://localhost:3000`. This means our Links will look like:

{% highlight ruby %}
"#{ENV['HOST']}/#{ApplicationRecord.endpoint_namespace}/#{Resource.type}"
{% endhighlight %}

For example:

{% highlight ruby %}
http://my-website.com/api/v1/employees
{% endhighlight %}

Finally, there's some boilerplate in `ApplicationController`:

{% highlight ruby %}
class ApplicationController < ActionController::API
  # Add Graphiti mixin to controllers
  include Graphiti::Rails
  # Support .json and .xml with the Responders gem
  include Graphiti::Responders

  # Customize response error code when we can't find a record by ID
  register_exception Graphiti::Errors::RecordNotFound,
    status: 404

  # Always respond with a JSONAPI-compliant errors payload
  # This hooks into a DSL for customizing status codes, messages,
  # etc. The 404 above is an example.
  rescue_from Exception do |e|
    handle_exception(e)
  end
end
{% endhighlight %}
