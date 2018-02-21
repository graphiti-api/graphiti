---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Pagination

> [View the JSONAPI specification](http://jsonapi.org/format/#fetching-pagination)

> [View the YARD Documentation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html#paginate-class_method)

> View the Sample App: [Server1](https://github.com/jsonapi-suite/employee_directory/compare/step_4_custom_sorting...step_5_pagination) \|&nbsp; [Server2](https://github.com/jsonapi-suite/employee_directory/compare/step_5_pagination...step_6_custom_pagination) \|&nbsp; [Client](https://github.com/jsonapi-suite/employee-directory-vue/compare/step_6_stats...step_7_pagination)

> [View the JS Documentation]({{ site.github.url }}/js/reads/pagination)

Pagination usually happens with no developer intervention, instead handled
automatically by an [Adapter]({{ site.github.url }}/ruby/alternate-datastores/adapters). To
customize:

{% highlight ruby %}
paginate do |scope, current_page, per_page|
  scope.page(current_page).per(per_page)
end
{% endhighlight %}

A real-life example might be replacing the default [Kaminari](https://github.com/kaminari/kaminari) gem with [will_paginate](https://github.com/mislav/will_paginate):

{% highlight ruby %}
paginate do |scope, current_page, per_page|
  scope.paginate(page: current_page, per_page: per_page)
end
{% endhighlight %}
