---
sectionid: error-handling
sectionclass: h1
title: Error Handling
is-parent: true
number: 20
---

We touched on [Error Objects](http://jsonapi.org/format/#errors) in the
[validations section](/#validations). Let's make this work for
any random error our application might throw:

```ruby
class ApplicationController < ActionController::API
  # ... code ...

  rescue_from Exception do |e|
    handle_exception(e)
  end
end
```

Now let's say we had `raise 'foo'` somewhere. Our API would return a 500
status code with:

```ruby
{
  errors: [
    code: 'internal_server_error',
    status: '500',
    title: 'Error',
    detail: "We've notified our engineers and hope to address this issue shortly.",
    meta: {}
  ]
}
```

This can all be customized. Let's say for all
`ActiveRecord::RecordNotFound` errors we want a 404 response code, with
the error `detail` providing a custom message:

```ruby
register_exception ActiveRecord::RecordNotFound,
  status: 422,
  message: ->(e) { "Couldn't find record with id #{e.id}" }
```

Would output:

```ruby
{
  errors: [
    code: 'not_found',
    status: '404',
    title: 'Error',
    detail: "Couldn't find record with id 123",
    meta: {}
  ]
}
```

You can register exceptions in `ApplicationController`, or any subclass
if you want a specific controller to handle a given error differently.

For more customization options, see the [jsonapi_errorable](https://github.com/jsonapi-suite/jsonapi_errorable) gem.

<div style="height: 3rem"></div>
{::options parse_block_html="true" /}
<div class='note info'>
###### Error Handling in Tests
  <div class='note-content'>
  You may want your test suite to throw errors, instead of returning
  this friendly output. Configure this using `JsonapiErrorable.disable!`:

```ruby
config.before :each do
  JsonapiErrorable.disable!
end

# enable for specific test
it 'does something' do
  JsonapiErrorable.enable!
  # ... code ...
end
```
  </div>
</div>
<div style="height: 25rem"></div>
