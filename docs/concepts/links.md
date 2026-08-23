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

Every relationship link has one of three modes: `true` (always rendered), `false` (no link at all), or `:on_demand` (rendered when the request asks with `?links=true`). The resource's [`relationship_links`](#relationship-links) sets the default mode, and the `link:` option overrides it per relationship:

```ruby
has_many :comments, link: false       # no link, whatever the resource default
has_many :comments, link: :on_demand  # only with ?links=true
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

### Relationship Links {#relationship-links}

`relationship_links` is the default mode for every relationship link on the resource, taking the same three values as the per-relationship `link:` option. To turn links off unless a relationship opts in:

```ruby
class ApplicationResource < Graphiti::Resource
  self.relationship_links = false
end

class PostResource < ApplicationResource
  has_many :comments               # no link
  has_many :top_comments, link: true  # rendered
end
```

A relationship with a custom `link do ... end` block is treated as `link: true` under a `false` default, on the theory that writing the block means wanting the link.

(`self.autolink` was the 1.x name for the `false`/`true` half of this setting. It still works, warns, and will be removed in 3.0.)

### Endpoint Validation {#endpoint-validation}

Endpoints are validated in two directions, each with its own setting.

`validate_requests` guards what comes in. A Resource refuses to serve a request whose path and action are not among its [endpoints](#resource-endpoints), which is what stops one Resource being reached through another's route:

```ruby
class ApplicationResource < Graphiti::Resource
  self.validate_requests = false
end
```

`validate_links` guards what goes out. Before rendering a relationship link, Graphiti checks that the target endpoint is actually routable for the action the link needs, which is `:show` for a `belongs_to` and `:index` otherwise. You never serialize a link that 404s. Custom `link do ... end` blocks and remote Resources are skipped:

```ruby
class ApplicationResource < Graphiti::Resource
  self.validate_links = false
end
```

Turn off `validate_links` when your links point at endpoints another service serves, and you still want the inbound guard.

(`self.validate_endpoints` set both at once. It still works, warns, and will be removed in 3.0.)

### Links-on-Demand {#links-on-demand}

To only render relationship links when requested in the URL with `?links=true`:

```ruby
class ApplicationResource < Graphiti::Resource
  self.relationship_links = :on_demand
end
```

`relationship_links` accepts `true` (always render, the default), `false` (no links), or `:on_demand`. Set it on `ApplicationResource` to apply everywhere, on an individual resource to override, or per relationship with `link:`. A relationship whose only content would be an unrequested on-demand link is omitted from the payload entirely, since JSON:API forbids empty relationship objects.

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
