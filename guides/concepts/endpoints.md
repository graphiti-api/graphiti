---
layout: page
---

<div markdown="1" class="toc col-md-3">
Endpoints
==========

* 1 [Overview](#overview)
  * [Endpoint logic](#endpoint-logic)
  * [Rails Integration](#rails-integration)
  * Without Rails
* 2 [Customizing Resources](#customizing-resource-behavior)
  * [Scope Overrides](#scope-overrides)
  * [Sideload Allowlist](#sideload-allowlist)
* 3 [Caching](#caching)
  * [ETags](#etags)
  * Action Caching
* 4 [Testing](#testing)

</div>

<div markdown="1" class="col-md-8">
## 1 Overview

**Endpoints** expose and customize
[Resources](/guides/concepts/resources).

It's important to remember that Resources themselves can operate
completely independently of a request or response:

{% highlight ruby %}
employees = EmployeeResource.all({
  filter: { title: 'engineer' },
  sort: '-created_at',
  page: { size: 10 },
  include: 'positions.department'
})

employees.map(&:first_name) # => ['Jane', 'John', ...]
employees.to_json # => { employees: [{ ... }] }
{% endhighlight %}

And Resources connect to other Resources. Our graph of data is defined
**outside** of the actual API.

Endpoints expose this graph to the world. We might choose to have a `/employees`
endpoint that can eager load comments (`?include=comments`), but never expose
`/comments` directly. Or, we could do the opposite: expose lazy-loading `/comments`,
but disallow eager loading from `/employees.` We can add caching rules,
or add an `/exemplary_employees` endpoint with special query overrides.

Finally, Endpoints are in charge of the [HTTP specification](https://tools.ietf.org/html/rfc2616):
request processing, response codes, caching, MIME types, and so on. If you're thinking
Rails, an Endpoint is the combination of a Route and Controller.

### 1.1 Endpoint Logic

Often, you won't need to customize Endpoints - especially if you're
using our [Rails Resource
generator](/guides/concepts/resources#generators). Endpoint logic mostly
concerns:

* Caching
* Side-effect behavior specific to the endpoint (e.g.: sending a
welcome email from `/users#create` but not `/admin/users#create`)
* Authorization (e.g `before_action`)
* Custom query parameter handling
* Validation handling
* Error handling
* Limiting Resource behavior
* Customizing Resource behavior

If your logic falls elsewhere, consider a Resource or Model.

### 1.2 Rails Integration

When using Rails, an endpoint is the combination of a Route and
Controller:

{% highlight ruby %}
# config/routes.rb
resources :posts, only: [:index]

# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def index
    posts = PostResource.all(params)
    respond_with(posts)
  end
end
{% endhighlight %}

You'll note that Graphiti hooks into Rails with a mixin (set when using
our application generator):

{% highlight ruby %}
class ApplicationController < ActionController::API
  include Graphiti::Rails

  # ... code ...
end
{% endhighlight %}

This gives us [#sideload_allowlist](#sideload-allowlist) and sets the
[context](/guides/concepts/resources#context).

## 2 Customizing Resources

### Scope Overrides

One common use case for endpoints is customizing the Resource
[base scope](/guides/concepts/resources#basescope). This causes a new
"starting point" for query building.

Consider the endpoints `/posts` (basic CRUD) and `/top_posts`. Though
both are associated to PostResource, `/top_posts` ensures that only
Posts with a certain number of upvotes get returned:

{% highlight ruby %}
def index
  base_scope = Post.where("upvotes > ?", 100)
  posts = PostResource.all(params, base_scope)
  respond_with(posts)
end
{% endhighlight %}

We're able to reuse all the other logic in PostResource - relationships,
filters, sorts, etc - while only returning "Top Posts".

### Sideload Allowlist

Resources define relationships to other resources. But we may not want
all those relationships exposed at a given endpoint.

Let's say we've defined relationships:

`Employee > Position > Department > Hardware > CostHistory`

It's reasonable to get an Employee, their Positions, and Departments for
those positions in a single request. But is it really valid to *also* pull down
all the hardware, as well as all the historical data on the cost of that hardware,
in a single request? Allowing the entire graph to be pulled down in a single request can cause excessive load on our
servers (and this is probably a better fit for lazy-loading via
[Links](/guides/concepts/links)).

Let's instead say that if we're entering the graph at `/employees`, the
furthest we can go is Department:

{% highlight ruby %}
class EmployeesController < ApplicationController
  self.sideload_allowlist = {
    index: { positions: 'department' }
  }

  # ... code ...
end
{% endhighlight %}

## Caching

### Etags

[ETags](https://robots.thoughtbot.com/introduction-to-conditional-http-caching-with-rails) are an important concept that is often overlooked. Etags tell browsers
that the response to a GET request hasn't changed since the last request and
can be safely pulled from the browser cache. If you care about sparse fieldsets,
you should care about ETags - if you're limiting fields to reduce payload size,
how about a payload size of **zero**?

It's important to note that ETags are set by default in Rails, by
checking the response body. This won't prevent queries from executing,
but it will save clients from downloading the response again if nothing
has changed.

Let's manually set an ETag:

{% highlight ruby %}
def index
  posts = PostResource.all(params)

  if stale?(posts.data)
    respond_with(posts)
  end
end
{% endhighlight %}

From the [documentation on #stale?](https://api.rubyonrails.org/v5.2.1/classes/ActionController/ConditionalGet.html#method-i-stale-3F):

> *In this case last_modified will be set by calling `maximum(:updated_at)` on the collection (the timestamp of the most recently updated record) and the etag by passing the object itself.*

Also consider the use case where data is ingested hourly. We can avoid a
query altogether by checking when the last ingestion ran:

{% highlight ruby %}
def index
  if stale?(EmployeeIngestion.last)
    employees = EmployeeResource.all(params)
    respond_with(employees)
  end
end
{% endhighlight %}

> **CAVEAT**: When setting ETags, consider sideloads. In the above examples
> we are checking to see the last update of an Employee, but we may be
> sideloading (and filtering) Positions as well. Use custom endpoints or
> [Sideload Allowlist](#sideload-allowlist) to mitigate this issue.

### Action Caching

TODO

## 4 Testing

If you have custom Endpoint logic, we suggest testing using an [API
Test](/guides/concepts/testing#api-tests).
