---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Sorting

> [View the JSONAPI specification](http://jsonapi.org/format/#fetching-sorting)

> [View the YARD Documentation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html#sort-class_method)

> View the Sample App: [Server1](https://github.com/jsonapi-suite/employee_directory/compare/step_2_add_custom_filter...step_3_basic_sorting) \|&nbsp; [Server2](https://github.com/jsonapi-suite/employee_directory/compare/step_3_basic_sorting...step_4_custom_sorting) \|&nbsp; [Client](https://github.com/jsonapi-suite/employee-directory-vue/compare/step_4_filtering...step_5_sorting)

> [View the JS Documentation]({{ site.github.url }}/js/reads/sorting)

Sorting usually happens with no developer intervention, instead handled
automatically by an [Adapter]({{ site.github.url }}/ruby/alternate-datastores/adapters). To
customize:

{% highlight ruby %}
sort do |scope, attribute, direction|
  scope.order(attribute => direction)
end
{% endhighlight %}

A real-life example might be sorting on a different table. Let's say an
Employee has many Positions, and `title` lives in the `positions` table:

{% highlight ruby %}
sort do |scope, attribute, direction|
  if attribute == :title
    scope.joins(:positions).order("positions.title #{direction}")
  else
    scope.order(attribute => direction)
  end
end
{% endhighlight %}

> Note: the same `sort` proc will fire for every sort parameter supplied
> in the request. In other words, yes - you can multisort!

#### Sorting Relationships

Prefix the sort parameter with the relevant [JSONAPI Type](http://jsonapi.org/format/#document-resource-identifier-objects) like so:

{% highlight bash %}
/blogs?include=posts&sort=posts.title
{% endhighlight %}
