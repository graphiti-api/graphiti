---
title: 'Persisting'
---

# Persisting {#persisting}

This page covers how Graphiti writes data: the persistence lifecycle, sideposting a graph of resources in one request, validation errors, and reading data back after a write.

Graphiti allows writing a graph of data in a single request. We'll do
the work of parsing the graph and ordering operations, so you can focus
on the part you care about: the logic for actually persisting an object.

By default, persistence operations are handled by your adapter, and the flow breaks into three steps: build or find the model, assign attributes to it, then save it.

Attributes are assigned up front, before the persistence hooks run. That means the model exists (populated but unwritten) before anything touches the database, and **the model you inspect is the model that saves**:

```ruby
employee = EmployeeResource.build(payload)

employee.data           # the model, attributes already assigned, nothing written yet
employee.data.valid?    # inspect it, or modify it
employee.save           # persists that same instance
```

Reading `data` repeatedly returns the same instance, and the attribute callbacks run only once no matter how often you read it. For an update, the proxy reads the persisted record until you apply the payload:

```ruby
proxy = EmployeeResource.find(payload)
proxy.data.first_name       # => "asdf", straight from the database
proxy.assign_attributes(payload)
proxy.data.first_name       # => "Jane", assigned but not yet persisted
proxy.save(action: :update)
```

`assign_attributes` validates the payload and runs your writable guards, but writes nothing. `#save` will not re-validate a payload it already validated, so inspecting the model costs no extra guard evaluations. `ResourceProxy#update` is the Rails-style shorthand that assigns and saves in one call.

You can override `#create`, `#update` and `#destroy` on a Resource, but you are encouraged **not** to. Use the hooks below instead. If you do override them, `#create` and `#update` receive an attributes hash while `#destroy` receives an id, and all three **must return the Model instance**. Graphiti processes any `writable: false` or guarded attributes before these methods run, and checks the returned Model for validation errors afterward, rolling back the transaction if any Model in the graph is invalid.

## Persistence Lifecycle Hooks {#persistence-lifecycle-hooks}

Let's dive into a persistence request. If you look at the code snippets in
the prior section, the flow breaks down into 3 steps:

* Build or find the model
* Assign attributes to the model
* Save

You can hook into each step:

```ruby
class PostResource < ApplicationResource
  before_attributes do |attributes|
    # Before attributes have been assigned to the model
  end

  after_attributes do |model|
    # After attributes have been assigned to the model
  end

  around_attributes :do_around_attributes

  def do_around_attributes(attributes)
    # before
    model_instance = yield attributes
    # after
  end

  before_save do |model|
    # After attributes assigned, but before persisting
  end

  after_save do |model|
    # After model has been saved
  end

  around_save :do_around_save

  def do_around_save(model)
    # before
    yield model
    # after
  end

  # This is an *override*
  # During #create, build a blank model instance
  # By default, we'd call adapter.build(model_class)
  def build(model_class)
    model_class.new
  end

  # This is an *override*
  # During #create/#update, assign new attributes to the model instance
  # By default, we'd call adapter.assign_attributes(model_instance, attributes)
  def assign_attributes(model_instance, attributes)
    attributes.each_pair do |key, value|
      model_instance.send(:"#{key}=", value)
    end
  end

  # This is an *override*
  # During #create/#update, actually save the model instance
  # By default, we'd call adapter.save(model_instance)
  def save(model_instance)
    model_instance.save
    model_instance
  end


  # This is an *override*
  # During #destroy, actually save the model instance
  # By default, we'd call adapter.destroy(model_instance)
  def delete(model_instance)
    model_instance.destroy
    model_instance
  end

  # Finally, you may want to hook around *all* the above steps:
  # Only applies to #create/#update
  around_persistence :do_around_persistence

  def do_around_persistence(attributes)
    attributes[:foo] = 'bar'
    model = yield # build/find, assign attrs, save
    model.update_counter_cache
  end
end
```

* All hooks have `only/except` options, e.g. `before_attributes only: [:update]`
* Most hooks can be called with an in-line block, or by passing a method
name (e.g. `before_attributes :do_something`). The exception is `around_*` hooks, which *must* be called with a method name.

When persisting multiple objects at once, we'll open a database
transaction, process each model individually, ensure all models pass
validation, then close the transaction. This means that if you raise an
error at any point, or any model does not pass validations, the
transaction will be rolled back.

You may want to perform an operation after all models have been
processed and validated, but before the transaction is closed. One
example is sending an email - you don't want to send if the models were
invalid, so `after_save` wouldn't work. And you still want to do it
*within* the transaction, so if your email server is down and an error
is raised the transaction gets rolled back.

For this scenario, use `before_commit`:

```ruby
before_commit do |model|
  PostMailer.with(post: model).some_email.deliver
end
```

## Sideposting {#sideposting}

The act of persisting multiple Resources in a single request is called
**Sideposting**. The payload mirrors the **sideloading** payload for
read operations, with minor additions.

Let's create a Post and associate it to an existing Blog in a single
request:

```ruby
# POST /api/v1/posts
{
  type: 'posts',
  attributes: { title: 'My post' },
  relationships: {
    blog: {
      data: {
        id: '1',
        type: 'blogs',
        method: 'update'
      }
    }
  }
}
```

The critical addition here is the `method` key. When we persist RESTful
Resources, we send a corresponding HTTP verb. This follows the same
pattern, adding a verb for each Resource in the graph. `method` can be
one of:

  * `create`
  * `update`
  * `destroy`
  * `disassociate` (e.g. `null` foreign key)

When we sidepost, all objects will be persisted within the same database
transaction, which rolls back if an error is raised or any objects are invalid.

### Create {#create}

Let's say we want to create a Post and its Blog in a single request.
You'll note that we don't have the `id` key to generate a [Resource Identifier](http://jsonapi.org/format/#document-resource-identifier-objects) (combination of `id` and `type`
that uniquely identifies a Resource).

To accomodate this, send an ephemeral `temp-id` (any UUID):

```ruby
{
  # POST /api/v1/posts
  {
    type: 'posts',
    attributes: { title: 'My post' },
    relationships: {
      blog: {
        data: {
          :'temp-id' => 'abc123',
          type: 'blogs',
          method: 'create'
        }
      }
    },
    included: [
      {
        :'temp-id' => 'abc123'
        type: 'blogs',
        attributes: { name: 'New Blog' }
      }
    ]
  }
}
```

This random UUID:

* Connects relevant sections of the payload.
* Tells clients how to associate their in-memory objects with the ids returned from the server.

### Expanded Example {#expanded-example}

Here we're updating a Post, changing the name of its associated Blog, creating a Tag, deleting one Comment, and disassociating (`null` foreign key) a different Comment, all in a single request:

```ruby
{
  data: {
    type: 'posts',
    id: 123,
    attributes: { title: 'Updated!' },
    relationships: {
      blog: {
        data: {
          type: 'blogs',
          id: 123,
          method: 'update'
        }
      },
      tags: {
        data: [{
          type: 'tags',
          temp-id: 's0m3uu1d',
          method: 'create'
        }]
      },
      comments: {
        data: [
          {
            type: 'comments',
            id: '123',
            method: 'destroy'
          },
          {
            type: 'comments',
            id: '456',
            method: 'disassociate'
          }
        ]
      }
    }
  },
  included: [
    {
      type: 'tags',
      :'temp-id' => 's0m3uu1d',
      attributes: { name: 'Important' }
    },
    {
      type: 'blogs',
      id: => '123',
      attributes: { name: 'Updated!' }
    }
  ]
}
```

## Validation Errors {#validation-errors}

When a persistence operation is attempted but the corresponding Resource
is invalid, the transaction will be rolled back and an [errors payload](http://jsonapi.org/format/#errors) will be returned
with a `422` response code:

```ruby
{
  errors: [{
    code:  'unprocessable_entity',
    status: '422',
    title: "Validation Error",
    detail: "Title can't be blank",
    source: { pointer: '/data/attributes/title' },
    meta: {
      attribute: :title,
      message: "can't be blank",
      code: :blank
    }
  }]
}
```

To get this functionality, your Model must adhere to the
[ActiveModel::Validations API](https://api.rubyonrails.org/classes/ActiveModel/Validations.html).

You get this for free with ActiveRecord, or it can be mixed in to any
PORO:

```ruby
class Post
  include ActiveModel::Validations
  validates :title, presence: true
end
```

Errors on associations will have a slightly expanded payload:

```ruby
{
  errors: [{
    code: 'unprocessable_entity',
    status: '422',
    title: 'Validation Error',
    detail: "Name can't be blank",
    source: { pointer: '/data/attributes/name' },
    meta: {
      relationship: {
        attribute: :name,
        message: "can't be blank",
        code: :blank,
        name: :pets,
        id: '444',
        type: 'pets'
      }
    }
  }]
}
```

When [Sideposting](#sideposting), the errors payload will contain all
invalid Resources in the graph.

## Read on Write {#read-on-write}

By default, the response of a persistence operation will mirror your
request. But sometimes you need control over the response. The most
common scenario is sideloading an additional entity - imagine creating
an order, and wanting the order's shipping information to come back in
the response.

You can do this by POSTing the payload as normal, but adding query
parameters to the URL:

```ruby
# POST /api/v1/orders?include=shipping_information

{
  type: 'orders',
  attributes: { ... }
}
```

This will sideload the shipping information in the response. When using
[Spraypaint](/js/), do this with:

```typescript
order.save({ returnScope: Order.includes('shipping_information') })
```
