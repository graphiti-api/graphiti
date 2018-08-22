---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Statistics

> [View the JS Documentation]({{ site.github.url }}/js/reads/statistics)

> [View the YARD Documentation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html#allow_stat-class_method)

> View the Sample App: [Server1](https://github.com/jsonapi-suite/employee_directory/compare/step_6_custom_pagination...step_7_stats) \|&nbsp; [Server2](https://github.com/jsonapi-suite/employee_directory/compare/step_7_stats...step_8_custom_stats) \|&nbsp; [Client](https://github.com/jsonapi-suite/employee-directory-vue/compare/step_5_sorting...step_6_stats)

Statistics are useful and common. Consider a datagrid listing posts - we
might want a "Total Posts" count displayed above the grid without firing
an additional request. Notably, that statistic **should** take into
account filtering, but **should not** take into account pagination.

You can whitelist stats in your `Resource`:

{% highlight ruby %}
allow_stat total: [:count]
{% endhighlight %}

And request them like so:

{% highlight bash %}
/posts?stats[total]=count
{% endhighlight %}

They will be returned in the [meta](http://jsonapi.org/format/#document-meta) section of the response:

{% highlight ruby %}
{
  # ...
  meta: {
    stats: {
      total: {
        count: 100
      }
    }
  }
}
{% endhighlight %}

You can run stats over specific attributes rather than `total`:

{% highlight ruby %}
allow_stat rating: [:average]
{% endhighlight %}

Adapters support the following statistics out-of-the-box: `count`,
`average`, `sum`, `maximum`, and `minimum`. You can also define custom
statistics:

{% highlight ruby %}
allow_stat rating: [:average] do
  standard_deviation do |scope, attr|
    # your standard deviation code here
  end
end
{% endhighlight %}
