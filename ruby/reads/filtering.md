---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Filtering

> [View the JSONAPI specification](http://jsonapi.org/format/#fetching-filtering)

> [View the YARD Documentation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html#allow_filter-class_method)

> View the Sample App: [Server1](https://github.com/jsonapi-suite/employee_directory/commit/cf501dd95f8d4211973092a673a9a449bf467a46) \|&nbsp; [Server2](https://github.com/jsonapi-suite/employee_directory/compare/step_1_add_filter...step_2_add_custom_filter) \|&nbsp; [Client](https://github.com/jsonapi-suite/employee-directory-vue/compare/step_3_includes...step_4_filtering)

> [View the JS Documentation]({{ site.github.url }}/js/reads/filtering)

Filters are usually one-liners, with the logic delegated to an [Adapter]({{ site.github.url }}/ruby/alternate-datastores/adapters).

{% highlight ruby %}
allow_filter :title
{% endhighlight %}

You can view `allow_filter` like a whitelist. We wouldn't want to
automatically support filters - otherwise sneaky users might filter our
`Employee`s to only those making a certain salary. Hence the whitelist.

To customize a filter:

{% highlight ruby %}
allow_filter :title do |scope, value|
  scope.where(title: value)
end
{% endhighlight %}

A real-life example might be a prefix query:

{% highlight ruby %}
allow_filter do |scope, value|
  scope.where(["title LIKE ?", "#{value}%"])
end
{% endhighlight %}

#### Filtering Relationships

Prefix the filter parameter with the relevant [JSONAPI Type](http://jsonapi.org/format/#document-resource-identifier-objects) like so:

{% highlight bash %}
/blogs?include=posts&filter[posts][title]=foo
{% endhighlight %}

#### Default Filters

> [View the YARD Documentation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Scoping/DefaultFilter.html)

You may want your scope to be filtered any time it is accessed - Perhaps
you only want to show `active` posts by default:

{% highlight ruby %}
default_filter :active do |scope|
  scope.where(active: true)
end
{% endhighlight %}

Default filters can be overridden if there is a corresponding
`allow_filter`. Given a `Resource`:

{% highlight ruby %}
allow_filter :active

default_filter :active do |scope|
  scope.where(active: true)
end
{% endhighlight %}

And the following requests:

{% highlight bash %}
/posts
/posts?filter[active]=false
{% endhighlight %}

The first will display only active posts, the second will display only
inactive posts.

#### Filter Conventions

There are some common naming conventions for supporting more complex filters:

{% highlight ruby %}
# greater than
allow_filter :id_gt

# greater than or equal to
allow_filter :id_gte

# less than
allow_filter :id_lt

# less than or equal to
allow_filter :id_lte

# prefix queries
allow_filter :title_prefix

# OR queries
allow_filter :active_or # true or false
{% endhighlight %}

> NOTE: **AND** queries are supported by default - just pass a
> comma-delimited list of values.

#### Filter Guards

You can conditionally allow filters based on runtime context.
Let's say only managers should be allowed to filter employees by salary:

{% highlight ruby %}
allow_filter :salary, if: :manager?

def manager?
  current_user.role == 'manager'
end
{% endhighlight %}

#### Filter Aliases

Aliases mostly come into play when supporting backwards
compatibility. Let's say we originally called the filter `fname` then
later wanted the more-expressive `first_name`. An alias allows is to
keep a one-liner with the correct naming, while still responding correctly
to `fname`:

{% highlight ruby %}
allow_filter :first_name, aliases: [:fname]
{% endhighlight %}
