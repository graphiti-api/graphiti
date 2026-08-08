---
title: 'Upgrading to Graphiti 2.0'
slug: /upgrading
---

# Upgrading to Graphiti 2.0

Graphiti 2.0 requires **Ruby 3.2+** and **ActiveSupport 7.1+**. Rails is not a dependency, but if you use it, 7.1+. Ruby 3.1 and earlier are past end of life, and Rails 6.1 and 7.0 do not support Ruby 3.2. Apps that cannot move yet should stay on the 1.x branch, which remains open for hotfixes.

## What you have to change {#what-you-have-to-change}

Four things, and three of them fail loudly if you skip them.

**1. Drop three gems.** `graphiti-rails`, `graphiti_spec_helpers` and `graphiti_errors` are now part of `graphiti` itself.

```diff title="Gemfile"
+ gem "graphiti", "~> 2.0.0.beta" # follows the betas and picks up 2.0 final when it ships
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

`Graphiti::Rails::Controller` now bundles all of it, and including it is required. Including it in `ApplicationController` matches 1.x behavior. Including it in an API base class scopes it and leaves the rest of the app alone. A controller without it gets no Graphiti context, no debugger, and none of Graphiti's exception handlers, so if a resource action sees an empty `Graphiti.context`, this include is what is missing.

The class-level DSL travels with it, which is the one failure you see before a request is ever served:

```ruby
class PostsController < ApplicationController
  self.sideload_allowlist = {index: [:comments]} # NoMethodError without the include
end
```

`sideload_allowlist` comes from `Graphiti::Context`, so a controller that never includes `Graphiti::Rails::Controller` raises `NoMethodError` while the class body is being loaded. Watch for base classes that were given `Graphiti::Rails::Responders` alone. Responders declares formats and nothing else, and does not carry the context.

`Graphiti::Rails::Responders` is separate and most apps do not need it. It exists for the [`responders`](https://github.com/heartcombo/responders) gem's `respond_with`, and depends on that gem, which is why it is not part of `Graphiti::Rails::Controller`.

</details>

**3. Update `around_persistence` hooks**, if you have any.

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

- If you inspect the model before saving, the attributes callbacks run at inspection time (in your controller, outside the save transaction). On the plain `save` path they run inside the transaction, at the same point as 1.x.
- Writable guards judge persisted state: a guard asking for the model gets a fresh build/find, never the current request's unsaved changes. A payload cannot influence its own authorization.
- Sideposted child models are still built and assigned during save, and `data` exposes the pre-assigned root model only.

</details>

**4. Wrap specs that assert on error payloads.**

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

<details>
<summary>Why it has to be a request spec</summary>

Exceptions propagate untouched in tests as of 2.0. A spec that asserts on a rendered error payload sees the exception raised instead, so wrap the request in `handle_request_exceptions`. The setup is [step 4 of the migration](/upgrading#what-you-have-to-change).

It has to be a request spec. Exceptions are rendered in Rack middleware, which controller specs bypass, so the same assertion in a controller spec never sees a rendered payload no matter how it is wrapped.

`handle_request_exceptions` replaces `GraphitiErrors.enable!` and `.disable!`, which toggled rendering globally. Wrapping the request scopes it to the example instead.

</details>

## Behavior changes to be aware of {#behavior-changes}

Nothing to do here. These change what a client receives or when a callback runs, and none of them warns you, because none of them is a rename.

<details>
<summary>A `belongs_to` renders resource ids when its foreign key already holds them, where 1.x sent only a link</summary>

A `belongs_to` now renders resource ids in the payload by default, where 1.x sent only a link:

```json
"employee": { "data": { "type": "employees", "id": "1" }, "links": { "related": "..." } }
```

The id comes from the foreign key already on the parent, so this costs no extra queries, and clients can resolve the relationship against data they already hold instead of following the link. `has_many` is unchanged, since answering there means a query per record.

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
<summary>`ConflictRequest` renders `code: "conflict"` at 409, where `graphiti-rails` surfaced it as a 500</summary>

Graphiti 1.x shipped two exception systems, `graphiti_errors` in core and `rescue_registry` in `graphiti-rails`, and both loaded in every Rails app. `rescue_registry` is now the only one, and installs automatically as a dependency.

Graphiti registers handlers for `InvalidRequest` (400), `ConflictRequest` (409), `RecordNotFound` (404), `RemoteWrite` (400) and `SingularSideload` (400), plus a fallback that renders anything else as JSON:API. Register your own on any controller:

```ruby
register_exception MyApp::Forbidden, status: 403
register_exception MyApp::Throttled, status: 429, handler: MyApp::ThrottleHandler
```

`register_exception` comes from `rescue_registry`, which adds it to every controller, so you do not need `Graphiti::Rails::Controller` to register your own exceptions or to have them rendered. What the include adds is Graphiti's own registrations above, plus the fallback that renders anything unregistered as JSON:API.

Only formats in `config.graphiti.handled_exception_formats` (default `[:jsonapi]`) are rendered by Graphiti. Everything else falls through to Rails.

If you subclassed `GraphitiErrors::ExceptionHandler`, note the interface changed with the gem: it is now `build_payload` / `formatted_response` / `status_code`, not `error_payload` / `status_code(error)`.

Registering and customizing handlers is covered in [Error Handling](/topics/error-handling).

**Conflicts now report as conflicts.** `Graphiti::Errors::ConflictRequest`, raised when a `PATCH` payload's id does not match the URL, used to render a 409 whose body said `code: "bad_request"`, `title: "Request Error"`. It now says `code: "conflict"`, `title: "Conflict Error"`. Under `graphiti-rails` this exception had no registered handler at all and surfaced as a 500, so for most apps this payload is new rather than changed.

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

## Deprecations you should fix {#deprecations-you-should-fix}

Every name below still works, warns, and will be removed in the next major. They're easy fixes though, so why not now?

| 1.x | 2.0 |
| --- | --- |
| `require "graphiti_spec_helpers/rspec"` | `require "graphiti/spec_helpers/rspec"` |
| `GraphitiSpecHelpers::RSpec` / `::Sugar` / `::Errors::*` | `Graphiti::SpecHelpers::*` |
| `require "graphiti-rails"` | remove / no longer needed |
| `include Graphiti::Rails` | `include Graphiti::Rails::Controller`|
| `include Graphiti::Responders` | `include Graphiti::Rails::Responders` |
| `jsonapi_context` | `graphiti_context` |
| `GraphitiErrors::Validation::Serializer` | `Graphiti::ErrorSerializers::Validation` |
| `GraphitiErrors::InvalidRequest::Serializer` | `Graphiti::ErrorSerializers::InvalidRequest` |
| `GraphitiErrors::ConflictRequest::Serializer` | `Graphiti::ErrorSerializers::ConflictRequest` |
| rspec shared contexts `"resource testing"`, `"remote api"` | `"graphiti resource testing"`, `"graphiti remote api"` |
| `GraphitiContextProxy` | `Graphiti::SpecHelpers::ContextProxy` |
| `context_namespace` | `current_action` |
| `Graphiti::Rails::DEPRECATOR` | `Graphiti::DEPRECATOR` (the old name still resolves) |
| `require "graphiti_errors"`, `require "graphiti/responders"` | remove / no longer needed |
| `always_include_resource_ids: true` on a relationship | `resource_ids: true` |

`RSpec.describe PostResource, type: :resource` still picks up the resource-testing context automatically. That has not changed.

## Removed outright {#removed-outright}

| 1.x | 2.0 |
| --- | --- |
| `include GraphitiErrors` | `register_exception` is available on every controller |
| `GraphitiErrors::ExceptionHandler` | subclass `Graphiti::Rails::ExceptionHandler` |
| `GraphitiErrors.enable!` / `.disable!` | `handle_request_exceptions` |
| `self.always_include_resource_ids_by_default` | `self.belongs_to_resource_ids_by_default`, which takes `:foreign_key`, `:always` or `:never` |

`always_include_resource_ids_by_default` only ever shipped in `2.0.0.beta.4`, so it is gone rather than deprecated and raises `NoMethodError` at class-definition time. It applied to every relationship type, and only a `belongs_to` can render resource ids without loading an association, so the replacement covers `belongs_to` alone. `= false` becomes `:never`. There is no equivalent of `= true`, because arming every collection API-wide is the behavior it was removed for. Use `:always` for `belongs_to`.

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
