---
layout: page
---

Customizing Error Responses
==========

Your application will automatically return a JSONAPI-compliant [error
object](http://jsonapi.org/format/#errors) whenever an error is raised.
That's due to this code in `ApplicationController`:

{% highlight ruby %}
# app/controllers/application_controller.rb
rescue_from Exception do |e|
  handle_exception(e)
end
{% endhighlight %}

If we put `raise 'foo'` in a controller somewhere, we'd see the
response:

{% highlight ruby %}
{
  errors: [
    code: 'internal_server_error',
    status: '500',
    title: 'Error',
    detail: "We've notified our engineers and hope to address this issue shortly.",
    meta: {}
  ]
}
{% endhighlight %}

This can all be customized. Let's say for all
`ActiveRecord::RecordNotFound` errors we want a 404 response code, with
the error `detail` providing a custom message:

{% highlight ruby %}
# app/controllers/application_controlle.rb
register_exception ActiveRecord::RecordNotFound,
  status: 422,
  message: ->(e) { "Couldn't find record with id #{e.id}" }
{% endhighlight %}

Would output:

{% highlight ruby %}
{
  errors: [
    code: 'not_found',
    status: '404',
    title: 'Error',
    detail: "Couldn't find record with id 123",
    meta: {}
  ]
}
{% endhighlight %}

You can register exceptions in `ApplicationController`, or any subclass
if you want a specific controller to handle a given error differently.

For more customization options, see the [jsonapi_errorable](https://github.com/jsonapi-suite/jsonapi_errorable) gem.

You may want your test suite to throw errors, instead of returning
this friendly output. Configure this using `JsonapiErrorable.disable!`:

{% highlight ruby %}
# spec/rails_helper.rb
config.before :each do
  JsonapiErrorable.disable!
end

# enable for specific test
it 'does something' do
  JsonapiErrorable.enable!
  # ... code ...
end
{% endhighlight %}

<br />
<br />
