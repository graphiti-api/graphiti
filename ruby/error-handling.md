---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Error Handling

> [View the jsonapi_errorable documentation](https://jsonapi-suite.github.io/jsonapi_errorable)

We want to follow the common best-practice of raising a specific error class:

{% highlight ruby %}
raise Errors::NotAuthorized
{% endhighlight %}

The problem is, this error would cause our server to return a `500`
status code, without much helpful detail. Instead, we want to
customize our responses based on the error thrown.

Enter [jsonapi_errorable](https://jsonapi-suite.github.io/jsonapi_errorable), which provides a simple DSL to do just that:

{% highlight ruby %}
# app/controllers/application_controller.rb
register_exception Errors::NotAuthorized, status: 403
{% endhighlight %}

Here we've customized the [error response](http://jsonapi.org/format/#errors) to send the HTTP status code `403` ([forbidden](https://httpstatuses.com/403)) whenever this particular exception class is raised.

Maybe our error class already has a message we want to display to the
user:

{% highlight ruby %}
register_exception Errors::NotAuthorized,
  status: 403,
  title: "Not Authorized",
  message: true,
{% endhighlight %}

For full documentation on everything you can do here, head over to
the [jsonapi_errorable](https://jsonapi-suite.github.io/jsonapi_errorable/) documentation.
