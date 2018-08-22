---
layout: page
---

How to Add Defaults
==========

You may need to change the default behavior or your API - perhaps you
want a default of 10 per page instead of 20. JSONAPI Suite provides
facilities that enable ***defaults*** that can be ***overridden*** - 10 per
page, unless elsewise specified by the user.

You can see these defaults in the [Resource documentation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html):

{% highlight ruby %}
default_filter :active do |scope|
  scope.where(active: true)
end

default_page_size(10)

default_sort([{ created_at: :desc }])
{% endhighlight %}

These can all be overriden by the user. In other words, hitting
`/posts` will only show active `Post`s, hitting
`/posts?filter[active]=false` will show inactive `Post`s. The same applies
for sorting and pagination.

A common pattern is for default filters to apply for all users, but
allow overrides for administrators. You can use the `:if` option to
restrict the override:

{% highlight ruby %}
# app/resources/post_resource.rb
allow_filter :active, if: :admin?

# app/controllers/posts_controller.rb
def admin?
  current_user.admin?
end
{% endhighlight %}

Now the default behavior is to view only active `Post`s, but
*administrators* can override this default.

<br />
<br />
