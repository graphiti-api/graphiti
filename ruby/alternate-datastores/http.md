---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Usage Without ActiveRecord: HTTP Services

> [Read First: Resources Overview]({{site.github.url}}/ruby/resources)

> [View the YARD Documentation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html)

This is a commonly requested example. Instead of using a full-fledged
client like `ActiveRecord` or `Trample`, we'll show low-level usage that
could apply to a variety of HTTP clients.

Remember, we always start with a "base scope" and modify that scope
depending on incoming request parameters. This same pattern could apply
to simply ruby hashes.

{% highlight ruby %}
def index
  render_jsonapi({})
end
{% endhighlight %}

Let's start by specifying a `Null` adapter - a pass-through adapter that
won't do anything without us explicitly overriding:

{% highlight ruby %}
# config/initializers/jsonapi.rb
require 'jsonapi_compliable/adapters/null'
{% endhighlight %}

{% highlight ruby %}
# app/resources/post_resource.rb
use_adapter JsonapiCompliable::Adapters::Null
{% endhighlight %}

Every time we get a request to sort, paginate, etc we'll need to modify
our hash. Here we'll simply merge parameters in the format our HTTP
client will accept:

{% highlight ruby %}
# app/resources/post_resource.rb
allow_filter :title do |scope, value|
  scope.merge!(conditions: { title: value })
end

sort do |scope, attribute, direction|
  scope.merge!(order: { attribute => direction })
end

paginate do |scope, current_page, per_page|
  offset = (current_page * per_page) - per_page
  scope.merge!(limit: per_page, offset: offset)
end
{% endhighlight %}

Finally, we need to tell the resorce how to resolve the query. In our
case, this means passing the built-up parameters into a method on our
HTTP client.

{% highlight ruby %}
# app/resources/post_resource.rb

# Remember, 'scope' here is a hash
def resolve(scope)
  results = MyHTTPClient.get(scope)
  results.map { |r| Post.new(r) }
end
{% endhighlight %}

Note that [#resolve](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html#resolve-instance_method) must return an array of `Model` instances. These
can be simple POROs, as you see above.

The final request would look something like this:

{% highlight ruby %}
HTTPClient.get \
  conditions: { title: "Hello World!" },
  order: { created_at: :desc },
  limit: 10,
  offset: 20
{% endhighlight %}

In our controller, if we used the lower-level [jsonapi_scope](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Base.html#jsonapi_scope-instance_method) method to introspect our results, we'd see an array of `Post` instances:

{% highlight ruby %}
# app/controllers/posts_controller.rb
def index
  scope = jsonapi_scope({})
  posts = scope.resolve
  puts posts # [#<Post:0x001>, #<Post:0x002>, ...]
  render_jsonapi(posts, scope: false)
end
{% endhighlight %}

If we found ourselves typing similar `Resource` code - always merging in
the same paramters to the hash - we'd probably want to package all this
up into an
[Adapter]({{site.github.url}}/ruby/alternate-datastores/adapters).
