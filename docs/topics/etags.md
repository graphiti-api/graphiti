---
title: 'ETags'
---

# ETags

Every resource proxy can compute a weak ETag for its current result set via `proxy.etag`. It's a plain string. Graphiti doesn't wire up `If-None-Match` handling or send `304 Not Modified` responses itself, so using it for HTTP conditional requests is up to your controller (for example, with Rails' own `fresh_when`/`stale?`).

## How it's computed

`etag` is a weak ETag built from the same cache key used for [caching](/topics/caching), but the *versioned* one:

```ruby
def etag
  "W/#{ActiveSupport::Digest.hexdigest(cache_key_with_version.to_s)}"
end
```

`cache_key_with_version` combines the scope's versioned cache key (which folds in every sideloaded proxy's versioned cache key and the underlying object's own `cache_key_with_version`), the query's cache key, and the resource cache tag if one is configured. Those are the same three ingredients described in the caching doc, except the scope portion here is version-aware rather than the plain identity-only key. In practice this means the ETag changes whenever the resolved records' `updated_at` values change, or whenever the rendering-relevant query params (fields, extra_fields, links, pagination_links, format) change.

Because it's derived purely from `cache_key_with_version`, calling `etag` twice on equivalent proxies (same resource, scope, and query) produces the same weak ETag, and it's always prefixed with `W/`.

## Using it

Since there's no built-in controller integration, you compute and use it explicitly:

```ruby
def index
  employees = EmployeeResource.all(params)
  response.headers["ETag"] = employees.etag
  render jsonapi: employees
end
```

Or combine it with Rails' conditional-GET support if you want automatic `304` handling:

```ruby
def index
  employees = EmployeeResource.all(params)
  fresh_when(etag: employees.etag)
end
```

## Relationship to resource-level caching

`etag` doesn't require `cache_resource` or `Graphiti.config.cache_rendering = true`. It's available on any resource proxy regardless of whether that resource participates in rendering caching. It does, however, share its key ingredients with the cache-rendering machinery: the same `cache_key_with_version` that ETags are hashed from is also what `Graphiti::Util::CacheDebug` tracks (as `current_version[:etag]` / `last_version[:etag]`) when the [debugger](/topics/debugging) reports on cache-key changes for a cached resource. So if you're seeing an ETag change unexpectedly, the debugger's cache section (enabled the same way as for [caching](/topics/caching)) will show you which cache-key segment changed.
