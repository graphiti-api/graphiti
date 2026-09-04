---
title: 'Caching'
---

# Caching

Graphiti can cache the rendered JSON response for a request, keyed off the underlying data and the parts of the query that affect rendering. This is opt-in at two levels: a global switch that enables cache-backed rendering, and a per-resource declaration that says which resources actually participate.

## Enabling it

First, tell Graphiti which cache store to use. Any object that responds to `fetch` works, so `Rails.cache` is the usual choice:

```ruby
Graphiti.cache = Rails.cache
```

Then turn on cache-backed rendering globally:

```ruby
Graphiti.configure do |config|
  config.cache_rendering = true
end
```

If `cache_rendering` is `true` but `Graphiti.cache` isn't set to something that responds to `fetch`, Graphiti raises `"You must configure a cache store in order to use cache_rendering. Set Graphiti.cache = Rails.cache, for example."` the first time `Graphiti.config.cache_rendering?` is checked.

`cache_rendering` alone doesn't cache anything, though. Each resource has to opt in with `cache_resource`:

```ruby
class EmployeeResource < ApplicationResource
  cache_resource expires_in: 5.minutes, tag: :cache_tag
end
```

`expires_in` defaults to `false` (no expiry) and `tag` defaults to `nil`. Calling `cache_resource` sets a resource-level flag that flows through every `all`/`find` call on that resource, so caching applies to both index and show-style requests.

## What actually gets cached

Only the rendered JSON is cached, not the database query. On render, if the resource proxy is cacheable and `Graphiti.config.cache_rendering?` is true, the renderer wraps the render call in `Graphiti.cache.fetch`, keyed by `"graphiti:render/#{proxy.cache_key}"`, versioned by `proxy.updated_at`, and expiring after `proxy.cache_expires_in`. If either condition is false, rendering happens normally with no cache involved.

## Cache key composition

`proxy.cache_key` combines three pieces, joined into a single expanded cache key:

- **Scope cache key**: the underlying object's own `cache_key` (typically an ActiveRecord relation's `cache_key`, so it reflects the resolved records), combined with the `cache_key` of every sideloaded resource proxy. Sideloading `positions` or `department` folds their cache keys into the parent's.
- **Query cache key**: a SHA1 digest over the parts of the query that affect *rendering*: `extra_fields`, `fields`, whether links are requested, whether pagination links are requested, and `format`. Filters, sorts, and pagination page/size are deliberately not part of this digest. Two requests that select the same rendering options produce the same query cache key even if they filter different data. This is why the key is always combined with the scope key, which does vary with the resolved records.
- **Resource cache tag**: if `cache_resource` was given a `tag:`, and the resource responds to that method, its value is appended as a third segment (e.g. `cache_resource tag: :cache_tag` calls `resource.cache_tag` and appends the result).

## Versioning and expiry

`proxy.updated_at` is the max `updated_at` across the resolved records (`@object.maximum(:updated_at)`) and every sideloaded proxy's `updated_at`, recursively. If that calculation raises, Graphiti logs the error and falls back to `Time.now`, so a broken `updated_at` calculation degrades to "always fresh" rather than raising into the request. This value is passed as the cache store's `version:` option, so it participates in the effective cache entry the same way `ActiveSupport::Cache::Store#fetch` normally handles versioning. `expires_in` is passed straight through to the cache store as-is from `cache_resource`.

## Debugging cache behavior

When the [debugger](/topics/debugging) is enabled and a request's rendering is actually cached (`proxy.cached?` and `cache_rendering?` both true), the debug output includes a cache section showing the cache key's name, whether it's "stable" or "volatile" (based on how often the key changes across requests), and, when the key does change, which cache-key segments were added or removed. This is built on `Graphiti::Util::CacheDebug`, which persists hit/miss counts in `Graphiti.cache` between requests to compute those stats. See [ETags](/topics/etags) for the related per-response version identifier this same infrastructure computes.
