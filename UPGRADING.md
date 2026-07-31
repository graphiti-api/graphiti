# Upgrading Graphiti

## 1.x to 2.0

### Requirements

Graphiti 2.0 requires Ruby 3.0+ and Rails 6.0+ (when using Rails).

### The model you inspect is the model that saves

Proxies returned by `build` and `find` now apply the request payload lazily, and expose the resulting model before anything is written:

```ruby
# Creates
resource = MyResource.build(params)
resource.data          # unsaved model, attributes applied
resource.data.valid?   # inspect before committing to anything
resource.save          # persists that same instance

# Updates
resource = MyResource.find(params)
resource.assign_attributes(params)
resource.data.changed  # dirty tracking works
resource.update

# or assign and save in one call, Rails-style
resource = MyResource.find(params)
resource.update(params)
```

`assign_attributes` is idempotent per payload, validation still runs before assignment, and the instance you inspect is the instance that saves.

### Breaking: around_persistence receives the model, not the attributes hash

To make the above hold, attributes are assigned to the model once, before the persistence hooks fire. `around_persistence` now wraps the save of an already-assigned model and receives that model:

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

To migrate, move attribute-hash modifications to `before_attributes` (which still receives the mutable hash, before assignment), or set the value on the model as above. Hooks that only wrap their yield - transactions, timing, post-save side effects - need no changes. Graphiti 1.x releases warn at runtime when a hook would be affected.

`before/around/after_attributes` and `before/around/after_save` are unchanged.

### Fine print

- If you inspect the model before saving, the attributes callbacks run at inspection time (in your controller, outside the save transaction). On the plain `save` path they run inside the transaction, at the same point as 1.x.
- Writable guards judge persisted state: a guard asking for the model gets a fresh build/find, never the current request's unsaved changes. A payload cannot influence its own authorization.
- Sideposted child models are still built and assigned during save; `data` exposes the pre-assigned root model only.
