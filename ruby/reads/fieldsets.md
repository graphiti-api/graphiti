---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Fieldsets

> [View the JSONAPI specification](http://jsonapi.org/format/#fetching-sparse-fieldsets)

> [View the JS Documentation]({{ site.github.url }}/js/reads/fieldsets)

#### Sparse Fieldsets

You'll get this for free. Given a serializer:

{% highlight ruby %}
# app/serializers/serializable_post.rb
class SerializablePost < JSONAPI::Serializable::Resource
  type :posts

  attribute :title
  attribute :description
  attribute :comment_count
end
{% endhighlight %}

And the request:

{% highlight bash %}
/posts?fields[posts]=title,comment_count
{% endhighlight %}

The `description` field will not be returned in the response.

#### Extra Fieldsets

> [View the YARD documentation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Scoping/ExtraFields.html)

The opposite of a "sparse fieldset" is an "extra fieldset". Perhaps you
have an attribute that is computationally expensive and should only be
returned when explicitly requested. Perhaps the majority of your clients
need the same fields (and can share the same cache) but one client needs
extra data (and you'll accept the cache miss).

To request an extra field, just specify it in your serializer:

{% highlight ruby %}
# app/serializers/serializable_employee.rb

extra_attribute :net_worth do
  1_000_000
end
{% endhighlight %}

In the URL, replace `fields` with `extra_fields`:

{% highlight bash %}
/posts?extra_fields[employees]=net_worth
{% endhighlight %}

The `net_worth` attribute will only be returned when explicitly
requested.

You may want to eager load some data only when a specific extra field is
requested. There's a hook for this in your `Resource`;

{% highlight ruby %}
# app/resources/employee_resource.rb

extra_field(employees: [:net_worth]) do |scope|
  scope.includes(:assets)
end
{% endhighlight %}
