---
title: 'Error Handling'
---

## Overview {#overview}

Whenever we have an application error, we want to respond with a
[JSONAPI-compliant errors payload](http://jsonapi.org/format/#errors).
This way clients have a predictable response detailing information about
the error.

```json
{
  "errors": [
    {
      "code": "internal_server_error",
      "status": "500",
      "title": "Internal Server Error"
    }
  ]
}
```

We'll also need a way to customize this payload. For instance, if a
`NotAuthorized` error is raised, the response should have a `403` status
code. For other errors, we may want to render a helpful error message:

```ruby
class ApplicationController < ActionController::API
  register_exception NotAuthorized, status: 403
  register_exception ShipmentDelayed,
    detail: ->(e) { "Contact us at 123-456-7899" }
  # ... code ...
end
```

Exception handling lives in Graphiti's Rails integration. Customizing the behavior based on error class happens in the [RescueRegistry](https://github.com/wagenet/rescue_registry) dependency.

### Setup {#setup}

Include the Rails integration in the controllers serving your resources:

```ruby
class ApplicationController < ActionController::Base
  include Graphiti::Rails::Controller
end
```

That registers handlers for Graphiti's own exceptions and renders anything else as JSON:API. `register_exception` itself is available on every controller without it. See below.

#### Displaying Raw Errors {#displaying-raw-errors}

When raw errors are on, the same payload carries the underlying exception under `meta.__raw_error__`:

```json
{
  "errors": [
    {
      "code": "internal_server_error",
      "status": "500",
      "title": "Internal Server Error",
      "meta": {
        "__raw_error__": {
          "message": "EmployeesController::SomeError",
          "backtrace": [
            "app/controllers/employees_controller.rb:5:in `index'",
            "..."
          ]
        }
      }
    }
  ]
}
```


It can be useful to display the raw error as part of the JSON response -
but you probably don't want to expose your stack trace to customers.
Let's only show raw errors for the `staging` environment:

```ruby
class ApplicationController < ActionController::API
  # ... code ...

  def show_detailed_exceptions?
    Rails.env.staging?
  end
end
```

Another common pattern is to only show raw errors when the user is
privileged to see them:

```ruby
class ApplicationController < ActionController::API
  # ... code ...

  def show_detailed_exceptions?
    current_user.admin?
  end
end

```

When `#show_detailed_exceptions?` returns `true`, you'll get the raw error class,
message, and backtrace in the JSON response.

## Usage {#usage}

### Basic {#basic}

Let's register an error with a custom response code:

```ruby
register_exception Errors::NotAuthorized, status: 403
```

Now if we `raise Errors::NotAuthorized`, the response code will be `403`.

Additional options:

```ruby
register_exception Errors::NotAuthorized,
  status: 403,
  title: "You cannot perform this action",
  detail: :exception, # render the raw error message
  detail: ->(error) { "Invalid Action" } # message via proc
```

[See full documentation in the RescueRegistry README](https://github.com/wagenet/rescue_registry).

All controllers will inherit any registered exceptions from their parent. They can also add their own. In this example, `FooError` will only throw a custom status code when thrown from `FooController`:

```ruby
class FooController < ApplicationController
  register_exception FooError, status: 422
end
```

### Replacing Graphiti's own registrations {#replacing}

Registering one of Graphiti's own errors again replaces its entry, and the last call wins. Keep the include above your own:

```ruby
class ApiController < ActionController::API
  include Graphiti::Rails::Controller

  register_exception Graphiti::Errors::UnsupportedPageSize, status: 422
end
```

### Titles and details {#copy}

Title and detail come from a locale key named after the error code:

```yaml
en:
  graphiti:
    errors:
      internal_server_error:
        title: "Something went wrong"
        detail: "We've probably received an error report already, but please contact us if the issue persists."
      not_found:
        title: "Not found"
```

`register_exception`'s own `title:` or `detail:` wins. With no key, the title is the HTTP status name and there is no detail.

Validation messages are keyed the same way, by the code the payload reports in `meta.code`:

```yaml
en:
  graphiti:
    errors:
      format: "%{attribute} %{message}"
      messages:
        missing: "is missing"
        invalid: "must be an object"
        invalid_relationship: "is not a valid relationship"
        unwritable_relationship: "cannot be written"
        unknown_attribute: "is an unknown attribute"
        unwritable_attribute: "cannot be written"
        type_error: "should be type %{type}"
        attribute_mismatch: "does not match the server endpoint"
```

`rails g graphiti:locale` writes that file, and `graphiti:install` calls it for you.

A message goes into `meta.message` bare, and `format` joins it to the attribute for `detail`. Where that word order does not suit, a message can name its own `%{attribute}`. Translations hold up inside concurrent sideloads, since `I18n.locale` travels to the pool threads.

### Error reporting {#error-reporting}

Graphiti's client errors are in Rails' `rescue_responses`, so a 400 or 404 renders without being reported to `Rails.error` as an unhandled failure. Rails still logs them, and everything else is reported as before.

This only changes what `Rails.error` hears about. An error tracker with its own middleware still catches everything, so you filter there too.

Exceptions you register yourself are not in there, so a 403 of your own still counts as a failure. Name it the same way Rails names its own:

```ruby
# config/application.rb
config.action_dispatch.rescue_responses["MyApp::Forbidden"] = :forbidden
```

To go the other way and hear about one of Graphiti's, drop it in an initializer, which runs after the railtie that installs them:

```ruby
# config/initializers/graphiti.rb
ActionDispatch::ExceptionWrapper.rescue_responses.delete("Graphiti::Errors::RecordNotFound")
```

### Advanced {#advanced}

The final option `register_exception` accepts is `handler`. Here you can inject your own error handling class that customize `RescueRegistry::ExceptionHandler`. For example:

```ruby
class MyCustomHandler < Graphiti::Rails::ExceptionHandler
  # self.exception accessible within all instance methods

  def status_code
    # ...customize...
  end

  def error_code
    # ...customize...
  end

  def title
    # ...customize...
  end

  def detail
    # ...customize...
  end

  def meta
    # ...customize...
  end
end

register_exception FooError, handler: MyCustomHandler
```

If you would like to use the same custom handler for all errors, override `default_exception_handler`:

```ruby
# app/controllers/application_controller.rb
def self.default_exception_handler
  MyCustomHandler
end
```

## Testing {#testing}

This pattern of globally rescuing exceptions makes sense when
running our live application...but during testing, we may want to
raise real errors and bypass this rescue logic.

This is why we turn off error-handling during tests by default:

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include Graphiti::Rails::TestHelpers
  # ... code ...

  config.before :each do
    handle_request_exceptions(false)
  end
end
```

If you want to turn this on for an individual test (so you can test
error codes, etc):

```ruby
before do
  handle_request_exceptions(true)
end
```
