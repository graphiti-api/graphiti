---
layout: page
---

<div markdown="1" class="toc col-md-3">
Links
==========

* 1 [Overview](#overview)
  * [Linking Relationships](#linking-relationships)
* 2 [Resource Endpoints](#resource-endpoints)
  * [Validation](#validation)
* 3 [Configuration](#configuration)
  * [Autolinking](#autolinking)
  * [Endpoint Validation](#endpoint-validation)
  * [Links-On-Demand](#links-on-demand)
  * [Custom Endpoint URLs](#custom-endpoint-urls)
  * [Without Rails](#without-rails)

</div>

<div markdown="1" class="col-md-8">
## 1 Overview

Links are useful for:

* Discoverability
* Lazy-loading
* Hiding implementation details

Let's say we're loading a Post and its "Top Comments". On Day One, we
might **eager load** the data like so:

`/posts/123?include=top_comments`

This fetches all the data in a single request. But after some UI
testing, we decide to add a "show comments" button. This way our
page can load quicker - it only needs to load the Post
initially, and loading Top Comments can be deferred. We
want to **lazy load** the relationship.

How would we do this? We *could* bake this logic into our next request:

`/comments?filter[post_id]=123&filter[upvotes][gte]=100`

But this requires the client to have knowledge of what a "Top Comment"
is. If this logic ever changed, we'd have to update every client - our
desktop app, mobile apps, reports, etc. Not to mention, third parties who
just want to display Top Comments are required to have this knowledge
and update their implementations as well.

Maybe we could hide what "Top Comment" means with a special endpoint:

`/top_comments?filter[post_id]=123`

But now clients *need to know* to hit this special endpoint instead of
the normal `/comments` endpoint. How would they know? What if
`top_comments` had special caching rules and *shouldn't* be used for
this purpose?

The main problem here is **there is no way to guarantee our lazy-loaded data will
match our eager loaded data**. Whether we fetch the Post and its Top
Comments in a single request, or lazy-load that data in a separate
request, the same data should always be returned.

[Links](http://jsonapi.org/format/#document-links) solve this problem. When we fetch the Post, the `top_comments`
relationship will contain a URL. Clients can simply follow that URL to
lazy-load the same data. We can now change the definition of a Top
Comment - 500 upvotes, factor in recency, apply downvotes - and no
clients need to change. They simple continue to follow a link.

### 1.1 Linking Relationships

When defining a relationship, we get a Link for free:

{% highlight ruby %}
class PostResource < ApplicationResource
  has_many :comments
end
{% endhighlight %}

> `/comments?filter[post_id]=123`

And when customizing a relationship with `params`, our Link will be
updated:

{% highlight ruby %}
has_many :comments do
  params do |hash|
    hash[:filter][:upvotes] = { gte: 100 }
  end
end
{% endhighlight %}

> `/comments?filter[post_id]=123&filter[upvotes][gte]=100`

Note: if you use the `scope` block directly, it may cause incorrect
links. Avoid using `scope` directly and instead use `params` and
`pre_load` if possible.

To manually generate a Link:

{% highlight ruby %}
has_many :comments do
  link do |post|
    helpers = Rails.application.routes.url_helpers
    helpers.comments_url(params: { filter: { post_id: post.id } })
    # or
    # http://example.com/api/v1/comments?filter[post_id]=123
  end
end
{% endhighlight %}

To avoid a Relationship Link altogether:

{% highlight ruby %}
has_many :comments, link: false
{% endhighlight %}

## 2 Resource Endpoints

To generate links, we need to associate a Resource to a URL. By default,
this happens automatically:

{% highlight ruby %}
class ApplicationResource < Graphiti::Resource
  # ... code ...
  self.endpoint_namespace = '/api/v1'
end

class PostResource < ApplicationResource
  # under the hood:
  primary_endpoint 'posts',
    [:index, :show, :create, :update, :destroy]
end
{% endhighlight %}

Which would generate links to `/api/v1/posts`.

### 2.1 Validation

Associating a Resource to an Endpoint serves two purposes. We've gone
over link generation. But we also want to make sure we're not linking to
something that doesn't actually exist. That's why we perform **Endpoint
Validation**.

If we tried to access the above resource at a `/comments` endpoint:

{% highlight ruby %}
class CommentsController < ApplicationController
  def index
    PostResource.all(params)
    # ...
  end
end
{% endhighlight %}

We'd get a `Graphiti::Errors::InvalidEndpoint` error. Endpoint
validation ensures that our auto-generated Links are actually valid.

To change the endpoint associated to a Resource:

{% highlight ruby %}
primary_endpoint 'special_posts', [:index, :show]
{% endhighlight %}

Or to alter only the **path**:

{% highlight ruby %}
self.endpoint[:path] = 'special_posts'
{% endhighlight %}

Or to alter only the **actions** supported:

{% highlight ruby %}
self.endpoint[:actions] = [:index, :show]
{% endhighlight %}

A resource may be accessible by multiple endpoints. Maybe `PostResource`
is also used at `/top_posts`. We want to keep all auto-generated links
pointing to `/posts` (the primary endpoint), but *allow* accessing
`PostResource` from the `/top_posts` endpoint:

{% highlight ruby %}
secondary_endpoint '/top_posts', [:index]
{% endhighlight %}

## 3 Configuration

### 3.1 Autolinking

To turn off automatically generated links:

{% highlight ruby %}
class ApplicationResource < Graphiti::Resource
  self.autolink = false
end
{% endhighlight %}

### 3.2 Endpoint Validation

To turn off Endpoint Validation:

{% highlight ruby %}
class ApplicationResource < Graphiti::Resource
  self.validate_endpoints = false
end
{% endhighlight %}

### 3.3 Links-on-Demand

To only render links when requested in the URL with `?links=true`:

{% highlight ruby %}
Graphiti.configure do |c|
  c.links_on_demand = true
end
{% endhighlight %}

### 3.4 Custom Endpoint URLs

To change the URL associated with a Resource:

{% highlight ruby %}
class PostResource < ApplicationResource
  # Most commonly seen in ApplicationResource
  self.endpoint_namespace = '/api/v1'

  primary_endpoint '/posts', [:index, :show]
  # OR
  self.endpoint[:path] = '/posts'
  # OR
  self.endpoint[:actions] = [:index, :show]
end
{% endhighlight %}

To generate a Relationship Link manually:

{% highlight ruby %}
has_many :comments do
  link do |post|
    helpers = Rails.application.routes.url_helpers
    helpers.comments_url(params: { filter: { post_id: post.id } })
    # or
    # http://example.com/api/v1/comments?filter[post_id]=123
  end
end
{% endhighlight %}

### 3.4 Without Rails

TODO

<!--TODO LINK GIF-->

</div>
