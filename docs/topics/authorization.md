---
title: 'Authorization'
---

Graphiti authorization happens at three independent layers: which records a query can ever see (`base_scope`), which attributes are readable/writable on those records, and which relationships can be sideloaded or sideposted. Each layer is enforced separately, so a guard on one doesn't imply anything about the others.

## Context

Guards need to know who's asking. Every Resource has access to `Graphiti.context` via the `#context` method (`lib/graphiti/resource.rb`). In a Rails app, including `Graphiti::Rails::Context` in your controller wraps every action in `Graphiti.with_context(graphiti_context, action_name.to_sym)`, and `graphiti_context` defaults to the controller instance itself (`lib/graphiti/rails/context.rb`):

```ruby
class ApplicationController < ActionController::Base
  include Graphiti::Rails::Context
end
```

That means `context` is your controller, and `context.current_user` (or whatever helper method your controller exposes) is available inside any Resource. Outside of Rails, set context manually:

```ruby
Graphiti.with_context(OpenStruct.new(current_user: user)) do
  PostResource.all
end
```

## Scoping records

Override `#base_scope` to limit which records a Resource can ever return, regardless of filters:

```ruby
class PostResource < ApplicationResource
  def base_scope
    Post.where(account_id: context.current_user.account_id)
  end
end
```

This runs before filtering, sorting, and pagination, so it can't be bypassed by query params. It applies to sideloads too: a `has_many`/`belongs_to`/`has_one` on the related Resource inherits that Resource's `base_scope` unless the relationship itself passes an explicit `base_scope:` option (`lib/graphiti/sideload.rb#base_scope`), so a scoped Resource stays scoped no matter which relationship it's reached through. See [Composing with Scopes](/concepts/resources#composing-with-scopes) for how `base_scope` fits into the rest of query building.

### Knowing which action you're in

`base_scope` runs for every action, and sometimes you want it to behave differently for a collection than for a single record. Use `context_namespace`, which is the current action name as a symbol. Rails sets it from `action_name` when wrapping the request (`lib/graphiti/rails/context.rb#wrap_graphiti_context`):

```ruby
def base_scope
  return Post.all if context_namespace == :show
  Post.where(account_id: context.current_user.account_id)
end
```

Reach for this rather than digging through the query object's internals. `context_namespace` is public and stable. The params inside `Graphiti::Query` are neither.

## Integrating with Pundit

Graphiti has no built-in Pundit integration, but the two compose cleanly: let Pundit's policy scope decide which records exist, and let Graphiti guards decide which fields and relationships are exposed.

Merge the policy scope in `base_scope`, so it can't be bypassed by query params:

```ruby
class ApplicationResource < Graphiti::Resource
  def base_scope
    Pundit.policy_scope!(context.current_user, model)
  end

  def current_user
    context.current_user
  end
end
```

Because `context` is the controller in Rails, per-record authorization stays where it always was: in the action, on the model the proxy hands you:

```ruby
def show
  post = PostResource.find(params)
  authorize post.data
  respond_with(post)
end
```

Note the split: the policy scope answers "which records may appear at all", `authorize` answers "may this user see this specific record", and [attribute guards](#attribute-guards) answer "which fields of it". Reaching for a policy inside an attribute guard works too, since guards can receive the model:

```ruby
attribute :salary, :integer, readable: :salary_visible?

def salary_visible?(model)
  Pundit.policy(current_user, model).salary?
end
```

## Attribute guards

Pass a symbol, string, or proc to `readable:`/`writable:` on an attribute to gate it per-request. The guard method can optionally accept the model instance and the attribute name as arguments. Arity decides what it receives, and the model is only resolved if a guard actually declares a parameter for it (`lib/graphiti/util/attribute_check.rb`, `lib/graphiti/resource.rb#guard_model`):

```ruby
class EmployeeResource < ApplicationResource
  attribute :salary, :integer, writable: :salary_writable?

  def salary_writable?(model_instance, attribute_name)
    context.current_user.admin? || context.current_user == model_instance.manager
  end
end
```

On create the model is a new unsaved instance. On update it's the persisted record. A failed `writable` guard on a request rejects the write with an `unwritable_attribute` validation error before anything is persisted (`lib/graphiti/request_validators/validator.rb`). A failed `readable` guard omits the attribute from the response (`lib/graphiti/util/serializer_attributes.rb`).

You can set the same guard for every attribute on a Resource with `attributes_readable_by_default`/`attributes_writable_by_default`, which also accept a symbol (`lib/graphiti/resource/configuration.rb`):

```ruby
class ApplicationResource < Graphiti::Resource
  self.attributes_writable_by_default = :writable_by_default?

  def writable_by_default?(model_instance, attribute_name)
    PolicyChecker.new(context.current_user).writable?(model_instance, attribute_name)
  end
end
```

Full option details, including `only`/`except` shorthand, live under [Limiting Behavior](/concepts/resources#limiting-behavior).

## Relationship guards

`has_many`, `belongs_to`, `has_one`, and `many_to_many` accept the same `readable:`/`writable:` guard shape, but unlike attribute guards, relationship guards take no arguments. Base the decision on `context` alone (`lib/graphiti/sideload.rb#evaluate_flag`):

```ruby
class EmployeeResource < ApplicationResource
  has_many :salary_histories, readable: :admin?, writable: :admin?

  def admin?
    context.current_user.admin?
  end
end
```

A failed `readable` guard silently scrubs the relationship from `?include=` before any records are fetched, and omits it from serialized output. A failed `writable` guard rejects a sidepost to that relationship with an `unwritable_relationship` validation error (`lib/graphiti/request_validators/validator.rb`).

The guard method can live on either side of the relationship: Graphiti first looks for it on the resource declaring the relationship, falling back to the related resource if it isn't defined there (`lib/graphiti/sideload.rb#guard_resource`). That lets you define the guard once on the related resource and cover every relationship that points at it.

To audit every guarded relationship across your app (useful before deploying a new guard), call `Graphiti.guarded_relationships`, which returns strings like `"EmployeeResource.salary_histories"` for every relationship whose `readable` or `writable` flag is a symbol, string, or proc (`lib/graphiti.rb#guarded_relationships`).

See [Customizing Relationships](/concepts/relationships#customizing-relationships) for the rest of the relationship option surface.

## Testing authorization

Set context in a spec with `Graphiti.with_context`:

```ruby
let(:ctx) { OpenStruct.new(current_user: double(admin?: true)) }

it 'exposes salary to admins' do
  Graphiti.with_context(ctx) { render }
  expect(d[0].salary).to eq(100_000)
end
```

See [Context](/topics/testing#context) in the testing guide for more on setting context in Resource and API specs.
