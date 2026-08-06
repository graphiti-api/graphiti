# Upgrading Graphiti

## 1.x to 2.0

Graphiti 2.0 requires **Ruby 3.2+** and **Rails 7.1+**. Ruby 3.1 and earlier are past end of life, and Rails 6.1 and 7.0 do not support Ruby 3.2. Apps that cannot move yet should stay on the 1.x branch, which remains open for hotfixes.

## What you have to change

**1. Drop three gems.** `graphiti-rails`, `graphiti_spec_helpers` and `graphiti_errors` are now part of `graphiti` itself.

```diff
# Gemfile
+ gem "graphiti"
- gem "graphiti-rails"
- gem "graphiti_spec_helpers"
- gem "graphiti_errors"
```

Graphiti raises at load if one is still installed — they ship files that collide with Graphiti's own, so leaving them in place means load order decides which copy you get.

**2. Include the Rails integration in your controllers.**

```ruby
class ApplicationController < ActionController::Base
  include Graphiti::Rails::Controller
end
```

Do this even if you already had `include Graphiti::Rails` there. That old spelling still sets the controller up so nothing breaks mid-upgrade, but it warns and will be removed in the next major version.

**3. Update `around_persistence` hooks**, if you have any. See [the model you inspect is the model that saves](#the-model-you-inspect-is-the-model-that-saves).

That is the whole required migration for most apps. Everything below either still works with a warning, or is a behaviour change to be aware of.

## Deprecations you should fix
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
| `Graphiti::Rails::DEPRECATOR` | `Graphiti::DEPRECATOR` (the old name still resolves) |
| `require "graphiti_errors"`, `require "graphiti/responders"` | remove / no longer needed |

`RSpec.describe PostResource, type: :resource` still picks up the resource-testing context automatically — that has not changed.

## Removed outright

| 1.x | 2.0 |
| --- | --- |
| `include GraphitiErrors` | `register_exception` is available on every controller |
| `GraphitiErrors::ExceptionHandler` | subclass `Graphiti::Rails::ExceptionHandler` |
| `GraphitiErrors.enable!` / `.disable!` | `handle_request_exceptions` |

## Without Rails

The serializers move but keep working: `Graphiti::ErrorSerializers::Validation`, `::InvalidRequest` and `::ConflictRequest` load with core and need no Rails.

`GraphitiErrors::ExceptionHandler`, which turned any exception into a JSON:API errors payload, is replaced by `RescueRegistry::ExceptionHandler` — a runtime dependency now, and usable outside Rails:

```ruby
require "rack" # or RescueRegistry::ExceptionHandler raises NameError on Rack
require "rescue_registry"

handler = RescueRegistry::ExceptionHandler.new(exception, status: 404)
handler.build_payload            # => {errors: [{code: :not_found, status: "404", ...}]}
handler.formatted_response(:json) # => [404, "{\"errors\":[...]}", :json]
```

`register_exception` and the rendering are Rails-only, but rescue_registry ships `RescueRegistry::ShowExceptions`, a Rack middleware for exactly this case — see its README.

`GraphitiErrors.logger` has no replacement; `Graphiti.logger` is the nearest thing.

## Controllers opt in

Until 2.0, Graphiti added itself to **every** controller in the application: an `around_action` wrapping each request in a Graphiti context, another wrapping it in the debugger, and a catch-all exception handler — on Devise controllers, admin controllers, HTML pages, everything.

`Graphiti::Rails::Controller` now bundles all of it, and where you include it decides the blast radius. `ApplicationController` matches 1.x behaviour; an API base class scopes it and leaves the rest of the app alone.

A controller without it gets no Graphiti context, no debugger, and none of Graphiti's exception handlers — so if a resource action sees an empty `Graphiti.context`, this include is what is missing.

`Graphiti::Rails::Responders` is separate and most apps do not need it. It exists for the [`responders`](https://github.com/heartcombo/responders) gem's `respond_with`, and depends on that gem, which is why it is not part of `Graphiti::Rails::Controller`.

## Exception handling goes through rescue_registry

Graphiti 1.x shipped two exception systems — `graphiti_errors` in core, `rescue_registry` in `graphiti-rails` — and both loaded in every Rails app. `rescue_registry` is now the only one, and installs automatically as a dependency.

Graphiti registers handlers for `InvalidRequest` (400), `ConflictRequest` (409), `RecordNotFound` (404), `RemoteWrite` (400) and `SingularSideload` (400), plus a fallback that renders anything else as JSON:API. Register your own on any controller:

```ruby
register_exception MyApp::Forbidden, status: 403
register_exception MyApp::Throttled, status: 429, handler: MyApp::ThrottleHandler
```

`register_exception` comes from `rescue_registry`, which adds it to every controller — you do not need `Graphiti::Rails::Controller` to register your own exceptions or to have them rendered. What the include adds is Graphiti's own registrations above, plus the fallback that renders anything unregistered as JSON:API.

Only formats in `config.graphiti.handled_exception_formats` (default `[:jsonapi]`) are rendered by Graphiti; everything else falls through to Rails.

If you subclassed `GraphitiErrors::ExceptionHandler`, note the interface changed with the gem: it is now `build_payload` / `formatted_response` / `status_code`, not `error_payload` / `status_code(error)`.

**Conflicts now report as conflicts.** `Graphiti::Errors::ConflictRequest` — raised when a `PATCH` payload's id does not match the URL — used to render a 409 whose body said `code: "bad_request"`, `title: "Request Error"`. It now says `code: "conflict"`, `title: "Conflict Error"`. Under `graphiti-rails` this exception had no registered handler at all and surfaced as a 500, so for most apps this payload is new rather than changed.

## Testing

Exceptions propagate untouched in tests. To assert on a rendered error payload, wrap the request:

```ruby
RSpec.configure do |config|
  config.include Graphiti::Rails::TestHelpers, type: :request
end

it "renders a 404" do
  handle_request_exceptions { get "/posts/999" }

  expect(response.status).to eq(404)
end
```

This has to be a request spec — exceptions are rendered in Rack middleware, which controller specs bypass.

## Persistence hooks

Attributes are now assigned to the model once, up front, before the persistence hooks run — which is what lets `build` and `find` hand you the model before anything is written. See the persistence guide for what that enables.

That changes one hook.

### around_persistence receives the model, not the attributes hash

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

To migrate, move attribute-hash modifications to `before_attributes` (which still receives the mutable hash, before assignment), or set the value on the model as above. Hooks that only wrap their yield — transactions, timing, post-save side effects — need no changes. Graphiti 1.x releases warn at runtime when a hook would be affected.

`before/around/after_attributes` and `before/around/after_save` are unchanged. Custom `create`/`update` adapter overrides keep their 1.x signatures.

One behaviour change inside the absorbed spec helpers: `Node#respond_to?` is now a proper `respond_to_missing?`, so `node.respond_to?(:first_name)` returns `true` for attributes present in the payload where it used to return `false`.

### Fine print

- If you inspect the model before saving, the attributes callbacks run at inspection time (in your controller, outside the save transaction). On the plain `save` path they run inside the transaction, at the same point as 1.x.
- Writable guards judge persisted state: a guard asking for the model gets a fresh build/find, never the current request's unsaved changes. A payload cannot influence its own authorization.
- Sideposted child models are still built and assigned during save; `data` exposes the pre-assigned root model only.
