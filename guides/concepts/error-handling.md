---
layout: page
---

<div markdown="1" class="toc col-md-3">
Error Handling
==========

* 1 [Overview](#overview)
  * [Setup](#setup)
  * [Displaying Raw Errors](#displaying-raw-errors)
* 2 [Usage](#usage)
  * [Basic](#basic)
  * [Advanced](#advanced)
  * [Logging](#logging)
* 3 [Testing](#testing)

</div>

<div markdown="1" class="col-md-8">

## 1 Overview

Whenever we have an application error, we want to respond with a
[JSONAPI-compliant errors payload](http://jsonapi.org/format/#errors).
This way clients have a predictable response detailing information about
the error.

<p align="center">
  <img width="100%" src="https://user-images.githubusercontent.com/55264/45879320-06096300-bd72-11e8-8920-6e83f4a2fce3.png">
</p>

To do these we'll need to globally rescue errors so that we can render
the correct response. As part of that logic, we'll need a way to say "if
a `NotAuthorized` error is raised, the response should have a `403`
status code", or "when this error is raised, send a helpful message to
the user about why the error occurred."

To do this we use the [Graphiti Errors](https://github.com/graphiti-api/graphiti_errors) gem.

### 1.1 Setup

Error handling is part of [Installation]({{site.github.url}}/guides/getting-started/installation),
but here's the code:

{% highlight ruby %}
# With Rails
# app/controllers/application_controller.rb
include Graphiti::Rails
rescue_from Exception do |e|
  handle_exception(e)
end

# Without Rails:
include GraphitiErrors
# ... your code to globally rescue errors ...
handle_exception(e)
{% endhighlight %}

We expose this directly so you can add additional logic, like sending
the error to NewRelic.

#### 1.1.1 Displaying Raw Errors

<p align="center">
  <img width="100%" src="https://user-images.githubusercontent.com/55264/45879208-9bf0be00-bd71-11e8-8427-282c5a426394.png">
</p>
<br />

It can be useful to display the raw error as part of the JSON response -
but you probably don't want to expose your stack trace to customers.
Let's only show raw errors for the `staging` environment:

{% highlight ruby %}
# app/controllers/application_controller.rb
rescue_from Exception do |e|
  handle_exception(e,  show_raw_error: Rails.env.staging?)
end
{% endhighlight %}

Another common pattern is to only show raw errors when the user is
privileged to see them:

{% highlight ruby %}
# app/controllers/application_controller.rb
rescue_from Exception do |e|
  handle_exception(e,  show_raw_error: current_user.developer?)
end
{% endhighlight %}

When `show_raw_error` is `true`, you'll get the raw error class,
message, and backtrace in the JSON response.

## 2 Usage

### 2.1 Basic

Let's register an error with a custom response code:

{% highlight ruby %}
register_exception Errors::NotAuthorized, status: 403
{% endhighlight %}

Now if we `raise Errors::NotAuthorized`, the response code will be
`403`.

Additional options:

{% highlight ruby %}
register_exception Errors::NotAuthorized,
  status: 403,
  title: "You cannot perform this action",
  message: true, # render the raw error message
  message: ->(error) { "Invalid Action" }, # message via proc
  log: false # don't log the error
{% endhighlight %}

All controllers will inherit any registered exceptions from their parent. They can also add their own. In this example, `FooError` will only throw a custom status code when thrown from `FooController`:

{% highlight ruby %}
class FooController < ApplicationController
  register_exception FooError, status: 422
end
{% endhighlight %}

### 2.2 Advanced

The final option `register_exception` accepts is `handler`. Here you can inject your own error handling class that customize `GraphitiErrors::ExceptionHandler`. For example:

{% highlight ruby %}
class MyCustomHandler < GraphitiErrors::ExceptionHandler
  def status_code(error)
    # ...customize...
  end

  def error_code(error)
    # ...customize...
  end

  def title
    # ...customize...
  end

  def detail(error)
    # ...customize...
  end

  def meta(error)
    # ...customize...
  end

  def log(error)
    # ...customize...
  end
end

register_exception FooError, handler: MyCustomHandler
{% endhighlight %}

If you would like to use the same custom handler for all errors, override `default_exception_handler`:

{% highlight ruby %}
# app/controllers/application_controller.rb
def self.default_exception_handler
  MyCustomHandler
end
{% endhighlight %}

### 2.3 Logging

You can assign any logger using `GraphitiErrors.logger =
your_logger`. When using Rails this defaults to `Rails.logger`.

## 3 Testing

This pattern of globally rescuing exceptions makes sense when
running our live application...but during testing, we may want to
raise real errors and bypass this rescue logic.

This is why we [turn off Graphiti Errors during tests by default](https://github.com/graphiti-api/employee_directory/blob/master/spec/rails_helper.rb#L35-L37):

{% highlight ruby %}
# spec/rails_helper.rb
RSpec.configure do |config|
  # ... code ...

  config.before :each do
    GraphitiErrors.disable!
  end
end
{% endhighlight %}

If you want to turn this on for an individual test (so you can test
error codes, etc):

{% highlight ruby %}
before do
  GraphitiErrors.enable!
end
{% endhighlight %}

<br />
<br />

</div>
