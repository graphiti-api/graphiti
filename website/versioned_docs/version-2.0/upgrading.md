---
title: 'Upgrading to Graphiti 2.0'
slug: /upgrading
---

# Upgrading to Graphiti 2.0

Graphiti 2.0 requires **Ruby 3.2+** and **ActiveSupport 7.1+**. Rails is not a dependency, but if you use it, 7.1+. Ruby 3.1 and earlier are past end of life, and Rails 6.1 and 7.0 do not support Ruby 3.2. Apps that cannot move yet should stay on the 1.x branch, which remains open for hotfixes.

## What you have to change {#what-you-have-to-change}

Five things, and four of them fail loudly if you skip them.

**1. Drop three gems.** `graphiti-rails`, `graphiti_spec_helpers` and `graphiti_errors` are now part of `graphiti` itself.

```diff title="Gemfile"
+ gem "graphiti", "~> 2.0"
- gem "graphiti-rails"
- gem "graphiti_spec_helpers"
- gem "graphiti_errors"
```

Graphiti raises at load if one is still installed, because they ship files that collide with Graphiti's own, so leaving them in place means load order decides which copy you get.

**2. Include the Rails integration in your controllers.**

```ruby
class ApplicationController < ActionController::Base
  include Graphiti::Rails::Controller
end
```

If the controller already has `include Graphiti::Rails`, replace it with `include Graphiti::Rails::Controller`.

<details>
<summary>What the include actually brings, and what a controller without it loses</summary>

Until 2.0, Graphiti added itself to **every** controller in the application: an `around_action` wrapping each request in a Graphiti context, another wrapping it in the debugger, and a catch-all exception handler, on Devise controllers, admin controllers, HTML pages, everything.

`Graphiti::Rails::Controller` now bundles all of it, and including it is required. Including it in `ApplicationController` matches 1.x behavior. Including it in an API base class scopes it and leaves the rest of the app alone. A controller without it gets no Graphiti context, no debugger, and none of Graphiti's exception handlers, so if a resource action sees an empty `Graphiti.context`, this include is what is missing. It also carries `ActionController::MimeResponds`, so `respond_to` works in `ActionController::API` apps, which under 1.x only came with `Graphiti::Rails::Responders`.

The class-level DSL travels with it, which is the one failure you see before a request is ever served:

```ruby
class PostsController < ApplicationController
  self.sideload_allowlist = {index: [:comments]} # NoMethodError without the include
end
```

`sideload_allowlist` comes from `Graphiti::Context`, so a controller that never includes `Graphiti::Rails::Controller` raises `NoMethodError` while the class body is being loaded. Watch for base classes that were given `Graphiti::Rails::Responders` alone. Responders declares formats and nothing else, and does not carry the context.

`Graphiti::Rails::Responders` is separate and most apps do not need it. It exists for the [`responders`](https://github.com/heartcombo/responders) gem's `respond_with`, and depends on that gem, which is why it is not part of `Graphiti::Rails::Controller`.

</details>

**3. Delete any `rescue_from` that called `handle_exception`**, if you have one.

```ruby
# 1.x, on a controller that included GraphitiErrors
rescue_from Exception do |e|
  handle_exception(e)
  Sentry.capture_exception(e) unless registered_exception?(e)
end
```

Rendering is middleware's job now, so `handle_exception` is gone and there is nothing left to call. Use `RescueRegistry.handles_exception?` if you still want the check. Exceptions reach your tracker's middleware on their own, and Graphiti's 400s and 404s stay out of `Rails.error` because they sit in Rails' `rescue_responses`.

**4. Update `around_persistence` hooks**, if you have any.

They now receive the already-assigned model where they used to receive the attributes hash, so a hook doing `attributes[:tenant_id] = current_tenant.id` raises. Move that to `before_attributes`, or set it on the model.

<details>
<summary>Before and after, and what else moved with it</summary>

Attributes are now assigned to the model once, up front, before the persistence hooks run, which is what lets `build` and `find` hand you the model before anything is written. See the [lifecycle hooks guide](/concepts/persisting#persistence-lifecycle-hooks) for what that enables.

That changes one hook.

#### around_persistence receives the model, not the attributes hash

It now wraps the save of an already-assigned model, and gets that model:

```ruby
# 1.x
def do_around_persistence(attributes)
  attributes[:tenant_id] = current_tenant.id
  model = yield
  model.log_saved!
end

# 2.0
def do_around_persistence(model)
  model.tenant_id = current_tenant.id # last chance to touch the model before save, inside the transaction
  saved = yield
  saved.log_saved!
end
```

To migrate, move attribute-hash modifications to `before_attributes` (which still receives the mutable hash, before assignment), or set the value on the model as above. Hooks that only wrap their yield, such as transactions, timing and post-save side effects, need no changes. Graphiti 1.x releases warn at runtime when a hook would be affected.

`before/around/after_attributes` and `before/around/after_save` are unchanged. Custom `create`/`update` adapter overrides keep their 1.x signatures.

#### Fine print

- If you inspect the model before saving, the attributes callbacks run at inspection time (in the controller) outside the save transaction, and before sideposted parents are persisted. On the plain `save` path they run inside the transaction, at the same point as 1.x. If a hook needs the foreign key of a sideposted parent, use `before_save` instead, which always gets the model with those keys set.
- A writable guard asking for the model gets a fresh build/find, never the current request's unsaved changes.
- Sideposted child models are still built and assigned during save, and `data` exposes the pre-assigned root model only.
- The 1.x runtime warning fires when a hook mutates the hash, which is all it can detect. A hook that only reads it (e.g. Rails.logger.info `attributes[:name]`) gets no warning and now reads the model instead. On ActiveRecord `model[:name]` still answers, but hash-only calls like `attributes.key?`, `dig` or `except` raise.

</details>

**5. Wrap specs that assert on error payloads.**

```ruby
RSpec.configure do |config|
  config.include Graphiti::Rails::TestHelpers, type: :request
end

it "renders a 404" do
  handle_request_exceptions { get "/posts/999" }

  expect(response.status).to eq(404)
end
```

Exceptions now propagate untouched in tests rather than rendering, so a spec expecting a 404 body sees the exception raised instead. This is the one that breaks the suite that would otherwise have told you the app was fine.

You do not have to edit them one by one. An `around` hook restores 1.x behavior for every request spec, and puts the setting back after each example:

```ruby
config.around(type: :request) { |example| handle_request_exceptions { example.run } }
```

<details>
<summary>Why it has to be a request spec</summary>

It has to be a request spec. Exceptions are rendered in Rack middleware, which controller specs bypass, so the same assertion in a controller spec never sees a rendered payload no matter how it is wrapped.

`handle_request_exceptions` replaces `GraphitiErrors.enable!` and `.disable!`, which toggled rendering globally. Wrapping the request scopes it to the example instead.

</details>

## Behavior changes to be aware of {#behavior-changes}

Nothing to do here. These change what a client gets back, or when a callback runs, and nothing warns you about them the way the renames below do.

<details>
<summary>A `belongs_to` renders resource ids when its foreign key already holds them, where 1.x sent only a link</summary>

A `belongs_to` now renders resource ids in the payload by default, where 1.x sent only a link:

```json
"employee": { "data": { "type": "employees", "id": "1" }, "links": { "related": "..." } }
```

The id comes from the foreign key already on the parent, so this costs no extra queries. `has_many` is unchanged, since answering there means a query per record.

Not every `belongs_to` qualifies. A remote target or a custom `primary_key` mean the foreign key is not the related id, a polymorphic target means one rendered type cannot cover every record, and a `scope` or `params` block or a `base_scope` mean the key might not survive the filter. Rendering ids for those means loading the association, so they stay opt-in as in 1.x and render nothing until you ask.

Run [`bin/rake graphiti:audit`](/topics/debugging#graphiti-audit) to see where your API stands: it lists every relationship that renders no ids, and why.

To go back to the old payload for one relationship:

```ruby
belongs_to :employee, resource_ids: false
```

Or for the whole API, on the resource everything inherits from:

```ruby
class ApplicationResource < Graphiti::Resource
  self.abstract_class = true

  self.belongs_to_resource_ids_by_default = :never
end
```

If you carry the `Sideload::BelongsTo` monkey patch from [#167](https://github.com/graphiti-api/graphiti/issues/167), delete it and set nothing. The default now covers the safe cases on its own. To force ids onto the rest the way the patch did, set `self.belongs_to_resource_ids_by_default = :always`, at a query per record for each one.

The three settings, and when a `belongs_to` cannot use its foreign key, are covered in [Customizing Relationships](/concepts/relationships#belongs-to-resource-ids).

</details>

<details>
<summary>A relationship with no ids and no link is left out of the payload, where 1.x rendered <code>meta: &#123;included: false&#125;</code></summary>

A relationship that renders neither resource ids nor a link used to look like this:

```json
"employee": { "meta": { "included": false } }
```

That shape comes from `jsonapi-serializable`, which fills in a relationship object it would otherwise render empty. It is not part of JSON:API and carries nothing a client can act on. Some clients read it as an empty relationship and clear data they already hold. 1.x left these out too when `links_on_demand` was on globally and the request did not ask for links.

To keep them, on one resource or on the resource everything inherits from:

```ruby
self.relationship_placeholders = true
```

</details>

<details>
<summary>A request with <code>?include=</code> always gets an <code>included</code> key back</summary>

When nothing comes back with the response, that key now holds an empty array. 1.x left it out entirely, so a client had to handle both a missing key and an empty one.

</details>

<details>
<summary>`ConflictRequest` renders `code: "conflict"` at 409, where `graphiti-rails` surfaced it as a 500</summary>

Graphiti 1.x shipped two exception systems, `graphiti_errors` in core and `rescue_registry` in `graphiti-rails`, and both loaded in every Rails app. `rescue_registry` is now the only one, and installs automatically as a dependency.

Graphiti registers handlers for `InvalidRequest` (400), `ConflictRequest` (409), `RecordNotFound` (404), `RemoteWrite` (400) and `SingularSideload` (400), plus a fallback that renders anything else as JSON:API. Register your own on any controller:

```ruby
register_exception MyApp::Forbidden, status: 403
register_exception MyApp::Throttled, status: 429, handler: MyApp::ThrottleHandler
```

`register_exception` comes from `rescue_registry`, which adds it to every controller, so you do not need `Graphiti::Rails::Controller` to register your own exceptions or to have them rendered. What the include adds is Graphiti's own registrations above, plus the fallback that renders anything unregistered as JSON:API.

Only formats in `config.graphiti.handled_exception_formats` (default `[:jsonapi]`) are rendered by Graphiti. Everything else falls through to Rails.

Registering one of these classes again replaces Graphiti's, and the last call wins. `graphiti_errors` apps often did, `UnsupportedPageSize` at 422 most of all. Put the include at the top of the class and your own registrations below it.

If you subclassed `GraphitiErrors::ExceptionHandler`, note the interface changed with the gem: it is now `build_payload` / `formatted_response` / `status_code`, not `error_payload` / `status_code(error)`.

Registering and customizing handlers is covered in [Error Handling](/topics/error-handling).

**Conflicts now report as conflicts.** `Graphiti::Errors::ConflictRequest`, raised when a `PATCH` payload's id does not match the URL, used to render a 409 whose body said `code: "bad_request"`, `title: "Request Error"`. It now says `code: "conflict"`, `title: "Conflict Error"`. Under `graphiti-rails` this exception had no registered handler at all and surfaced as a 500, so for most apps this payload is new rather than changed.

</details>

<details>
<summary>A 500 no longer claims your engineers have been notified</summary>

`rescue_registry` gave every 5xx that detail. Graphiti drops it, so a 500 renders `code`, `status` and `title` alone. To say something there, set a locale key rather than subclassing a handler:

```yaml
en:
  graphiti:
    errors:
      internal_server_error:
        title: "Something went wrong"
        detail: "We've probably received an error report already, but please contact us if the issue persists."
```

`rails g graphiti:locale` writes the file for you. Keyed by error code, so it works for any status. See [Error Handling](/topics/error-handling#copy).

</details>

<details>
<summary>`Node#respond_to?` answers `true` for any attribute present in the payload</summary>

`Node#respond_to?` is now a proper `respond_to_missing?`, so `node.respond_to?(:first_name)` returns `true` for attributes present in the payload where it used to return `false`. Nothing to do unless a spec asserted on the old `false`.

The node helpers are covered in [#jsonapi_data](/topics/testing#jsonapi-data).

</details>

<details>
<summary>Attributes are assigned before the persistence hooks run, so inspecting a model first moves the attributes callbacks outside the save transaction</summary>

If you inspect the model before saving, the attributes callbacks run at inspection time, in your controller and outside the save transaction. On the plain `save` path they run inside the transaction, at the same point as 1.x.

The hooks and their order are covered in [Persistence Lifecycle Hooks](/concepts/persisting#persistence-lifecycle-hooks).

</details>

<details>
<summary>`ActiveSupport::CurrentAttributes` now flow into concurrent sideloads</summary>

Since 1.8, `Current` was empty inside a concurrent sideload, so `Current.user` read nothing in production. It now reads what it did in the controller. Workarounds that resolved `Current` values on the request thread can go. See [Concurrency](/concepts/resources#concurrency).

</details>

## Deprecations you should fix {#deprecations-you-should-fix}

Every name below still works, warns, and goes away in the next major. They're all pretty easy fixes though, so why not now?

### Requires you can delete {#deprecated-requires}

| 1.x | 2.0 |
| --- | --- |
| `require "graphiti-rails"` | remove / no longer needed |
| `require "graphiti_errors"`, `require "graphiti/responders"` | remove / no longer needed |
| `require "graphiti_spec_helpers/rspec"` | `require "graphiti/spec_helpers/rspec"` |

### Includes and constants {#deprecated-includes}

| 1.x | 2.0 |
| --- | --- |
| `include Graphiti::Rails` | `include Graphiti::Rails::Controller`|
| `include Graphiti::Responders` | `include Graphiti::Rails::Responders` |
| `jsonapi_context` | `graphiti_context` |
| `Graphiti::Rails::DEPRECATOR` | `Graphiti::DEPRECATOR` (the old name still resolves) |

### Request context {#deprecated-context}

| 1.x | 2.0 |
| --- | --- |
| `context_namespace` | `current_action` |
| `Graphiti.context[:namespace]` | `current_action` |

### Error serializers {#deprecated-error-serializers}

| 1.x | 2.0 |
| --- | --- |
| `GraphitiErrors::Validation::Serializer` | `Graphiti::ErrorSerializers::Validation` |
| `GraphitiErrors::InvalidRequest::Serializer` | `Graphiti::ErrorSerializers::InvalidRequest` |
| `GraphitiErrors::ConflictRequest::Serializer` | `Graphiti::ErrorSerializers::ConflictRequest` |

### Spec helpers {#deprecated-spec-helpers}

| 1.x | 2.0 |
| --- | --- |
| `GraphitiSpecHelpers::RSpec` / `::Sugar` / `::Errors::*` | `Graphiti::SpecHelpers::*` |
| `include Graphiti::SpecHelpers::Sugar` (`d`, `included`, `errors`, `dt`) | call `jsonapi_data`, `jsonapi_included`, `jsonapi_errors`, `json_datetime` directly |
| rspec shared contexts `"resource testing"`, `"remote api"` | `"graphiti resource testing"`, `"graphiti remote api"` |
| `GraphitiContextProxy` | `Graphiti::SpecHelpers::ContextProxy` |

### Move these off `Graphiti.config` {#deprecated-global-config}

These are now resource settings. Set them on `ApplicationResource` to keep the old API-wide behavior, or on individual resources to scope them.

| 1.x | 2.0 |
| --- | --- |
| `Graphiti.config.links_on_demand = true` | `self.relationship_links = :on_demand` |
| `Graphiti.config.pagination_links = true` | `self.page_links = true` |
| `Graphiti.config.pagination_links_on_demand = true` | `self.page_links = :on_demand` |
| `Graphiti.config.typecast_reads = false` | `self.typecast_reads = false` |

### Link rendering {#deprecated-links}

| 1.x | 2.0 |
| --- | --- |
| `self.autolink = false` | `self.relationship_links = false` |

Link rendering is one mode per link now. It takes `true`, `false`, or `:on_demand`, which renders only when the request asks with `?links=true`. `self.relationship_links` sets the resource default and `link:` overrides it per relationship.

One behavior shift: `link: true` on a resource now always renders, even when the resource is `:on_demand`. Under the old global `links_on_demand` it stayed hidden until `?links=true`, so change those to `link: :on_demand`.

### Pagination {#deprecated-pagination}

| 1.x | 2.0 |
| --- | --- |
| `self.default_page_size = 10` | `self.page_default_size = 10` |
| `self.max_page_size = 500` | `self.page_max_size = 500` |
| `self.cursor_paginatable = true` | `self.page_cursors = true` |

Everything relating to the `page` param shares its prefix: `page_default_size`, `page_max_size`, `page_cursors` and `page_links`. The on-demand param follows, so use `?page_links=true` (`?pagination_links=true` still works). `page_links` takes the same three modes as `relationship_links`, but has no per-relationship level.

### Filter blanks {#deprecated-filter-blanks}

| 1.x | 2.0 |
| --- | --- |
| `self.filters_accept_nil_by_default = true` | `self.filter_blanks_treated_as = :null` |
| `self.filters_deny_empty_by_default = true` | `self.filter_blanks_treated_as = :rejected` |
| `filter :name, allow_nil: true` | `filter :name, blanks: :null` |
| `filter :name, deny_empty: true` | `filter :name, blanks: :rejected` |

`allow_nil:` and `deny_empty:` were two booleans answering one question, and they contradicted each other on `"null"`. The empty check raised before the coercion could run. One `blanks:` option replaces them, taking `:literal`, `:null` or `:rejected`, defaulted by `filter_blanks_treated_as`.

### Endpoint validation {#deprecated-endpoint-validation}

| 1.x | 2.0 |
| --- | --- |
| `self.validate_endpoints = false` | `self.validate_requests = false`, `self.validate_links = false` |

`validate_endpoints` did two unrelated jobs, so it split. `validate_requests` refuses requests to undeclared endpoints, and `validate_links` refuses to render links to unroutable ones. The old name sets both, and turning off link validation no longer disarms the inbound guard.

### Relationship resource ids {#deprecated-resource-ids}

| 1.x | 2.0 |
| --- | --- |
| `always_include_resource_ids: true` on a relationship | `resource_ids: true` |

The resource-wide version of this setting was removed rather than deprecated. See [`always_include_resource_ids_by_default`](#removed-outright) below.

## Removed outright {#removed-outright}

| 1.x | 2.0 |
| --- | --- |
| `include GraphitiErrors` | `include Graphiti::Rails::Controller`, and `register_exception` is on every controller either way |
| `GraphitiErrors::ExceptionHandler` | subclass `Graphiti::Rails::ExceptionHandler` |
| `GraphitiErrors.enable!` / `.disable!` | `handle_request_exceptions` |
| `self.always_include_resource_ids_by_default` | `self.belongs_to_resource_ids_by_default`, which takes `:foreign_key`, `:always` or `:never` |
| `Adapters::ActiveRecord#create` / `#update` | override `#save` |

`always_include_resource_ids_by_default` raises `NoMethodError` at class-definition time. It applied to every relationship type, and only a `belongs_to` can render resource ids without loading an association, so the replacement covers `belongs_to` alone. `= false` becomes `:never`. There is no equivalent of `= true`, because arming every collection API-wide is the behavior it was removed for. Use `:always` for `belongs_to`.

## Without Rails {#without-rails}

<details>
<summary>Using the error serializers and exception handling outside Rails</summary>

The serializers move but keep working: `Graphiti::ErrorSerializers::Validation`, `::InvalidRequest` and `::ConflictRequest` load with core and need no Rails.

`GraphitiErrors::ExceptionHandler`, which turned any exception into a JSON:API errors payload, is replaced by `RescueRegistry::ExceptionHandler`, a runtime dependency now, and usable outside Rails:

```ruby
require "rack" # or RescueRegistry::ExceptionHandler raises NameError on Rack
require "rescue_registry"

handler = RescueRegistry::ExceptionHandler.new(exception, status: 404)
handler.build_payload            # => {errors: [{code: :not_found, status: "404", ...}]}
handler.formatted_response(:json) # => [404, "{\"errors\":[...]}", :json]
```

`register_exception` and the rendering are Rails-only, but rescue_registry ships `RescueRegistry::ShowExceptions`, a Rack middleware for exactly this case. See its README.

`GraphitiErrors.logger` has no replacement. `Graphiti.logger` is the nearest thing.

</details>
