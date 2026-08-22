---
title: 'Links'
---

# Links

## Overview {#overview}

A [Link](http://jsonapi.org/format/#document-links) is a URL Graphiti puts in a relationship, pointing at the data so a client can fetch it separately. Every relationship gets one automatically:

```ruby
class PostResource < ApplicationResource
  has_many :comments
end
```

`GET /posts/123` renders the `comments` relationship with a `links.related` of `/comments?filter[post_id]=123`. The client follows that URL when it wants the comments, rather than asking for them up front with `?include=comments`.

### Why links {#why-links}

The URL matters most when the relationship means something more specific than "all the comments". Say `top_comments` is defined as 100 upvotes or more. A [`params` block](#linking-relationships) puts that into the generated Link, and the client still follows a URL.

The alternative is for clients to build that query themselves, which means every client (desktop, mobile, third-party) has to know what a "Top Comment" is and ship an update whenever the definition changes. Hiding it behind a dedicated `/top_comments` endpoint moves the problem rather than solving it: clients still have to know to hit a special endpoint, and nothing keeps its definition in sync with the eager-loaded one.

With a Link, the definition lives in one place. Change it to 500 upvotes, factor in recency, subtract downvotes: clients keep following the same URL.


## Linking Relationships {#linking-relationships}

When defining a relationship, we get a Link for free:

```ruby
class PostResource < ApplicationResource
  has_many :comments
end
```

> `/comments?filter[post_id]=123`

And when customizing a relationship with `params`, our Link will be
updated:

```ruby
has_many :comments do
  params do |hash|
    hash[:filter][:upvotes] = { gte: 100 }
  end
end
```

> `/comments?filter[post_id]=123&filter[upvotes][gte]=100`

Note: if you use the `scope` block directly, it may cause incorrect links. Avoid using `scope` directly and instead use `params` and `pre_load` if possible.

To manually generate a Link:

```ruby
has_many :comments do
  link do |post|
    helpers = Rails.application.routes.url_helpers
    helpers.comments_url(params: { filter: { post_id: post.id } })
    # or
    # http://example.com/api/v1/comments?filter[post_id]=123
  end
end
```

To avoid a Relationship Link altogether:

```ruby
has_many :comments, link: false
```

## Resource Endpoints {#resource-endpoints}

To generate links, we need to associate a Resource to a URL. By default,
this happens automatically:

```ruby
class ApplicationResource < Graphiti::Resource
  # ... code ...
  self.endpoint_namespace = '/api/v1'
end

class PostResource < ApplicationResource
  # under the hood:
  primary_endpoint 'posts',
    [:index, :show, :create, :update, :destroy]
end
```

Which would generate links to `/api/v1/posts`.

### Validation {#validation}

Associating a Resource to an Endpoint serves two purposes. We've gone
over link generation. But we also want to make sure we're not linking to
something that doesn't actually exist. That's why we perform **Endpoint
Validation**.

If we tried to access the above resource at a `/comments` endpoint:

```ruby
class CommentsController < ApplicationController
  def index
    PostResource.all(params)
    # ...
  end
end
```

We'd get a `Graphiti::Errors::InvalidEndpoint` error. Endpoint
validation ensures that our auto-generated Links are actually valid.

To change the endpoint associated to a Resource:

```ruby
primary_endpoint 'special_posts', [:index, :show]
```

Or to alter only the **path**:

```ruby
self.endpoint[:path] = 'special_posts'
```

Or to alter only the **actions** supported:

```ruby
self.endpoint[:actions] = [:index, :show]
```

A resource may be accessible by multiple endpoints. Maybe `PostResource` is also used at `/top_posts`. We want to keep all auto-generated links pointing to `/posts` (the primary endpoint), but *allow* accessing `PostResource` from the `/top_posts` endpoint:

```ruby
secondary_endpoint '/top_posts', [:index]
```

## Configuration {#configuration}

### Autolinking {#autolinking}

To turn off automatically generated links:

```ruby
class ApplicationResource < Graphiti::Resource
  self.autolink = false
end
```

### Endpoint Validation {#endpoint-validation}

To turn off Endpoint Validation:

```ruby
class ApplicationResource < Graphiti::Resource
  self.validate_endpoints = false
end
```

### Links-on-Demand {#links-on-demand}

To only render relationship links when requested in the URL with `?links=true`:

```ruby
class ApplicationResource < Graphiti::Resource
  self.relationship_links = :on_demand
end
```

`relationship_links` accepts `true` (always render, the default), `false` (never render), or `:on_demand`. Set it on `ApplicationResource` to apply everywhere, or on an individual resource to override.

### Pagination Links {#pagination-links}

Requesting large collections can make for slow responses. [Pagination](https://jsonapi.org/format/#fetching-pagination) breaks the response into smaller pieces, and pagination links tell the client how to walk them. They can appear in a response two ways.

#### Showing by default {#pagination-links-showing-by-default}

Every collection response returns pagination links:

```ruby
class ApplicationResource < Graphiti::Resource
  self.page_links = true
end
```

#### When requested {#pagination-links-when-requested}

Links are rendered only when the request asks for them with `?pagination_links=true`. Worth doing when the collection is large: the `last` link needs a total count, so rendering links costs a `stat(:total, :count)` on every request that gets them.

```ruby
class ApplicationResource < Graphiti::Resource
  self.page_links = :on_demand
end
```

Like `relationship_links`, `pagination_links` accepts `true`, `false` (the default), or `:on_demand`, and can be set per resource.

Pagination links won't show up for *#show* actions.

### Custom Endpoint URLs {#custom-endpoint-urls}

To change the URL associated with a Resource:

```ruby
class PostResource < ApplicationResource
  # Most commonly seen in ApplicationResource
  self.endpoint_namespace = '/api/v1'

  primary_endpoint '/posts', [:index, :show]
  # OR
  self.endpoint[:path] = '/posts'
  # OR
  self.endpoint[:actions] = [:index, :show]
end
```
