---
sectionid: nested-relationships
sectionclass: h2
title: Nested Relationships
number: 23
parent-id: jsonapi-plus
---

We've already mentioned nested relationships, but this is actually not
currently part of the core JSON API spec. We accept PUT or POST
payloads with nested attributes. The payload is the same as a
sideloaded response, with the addition of a `method` (called "sideposting"). Here we'll update
an employee and position, while destroying the department for that
position. If any of these error or fail validations, the transaction
will be rolled back:

```ruby
{
  data: {
    id: '1',
    type: 'employees',
    attributes: { name: 'Homer Simpson' },
    relationships: {
      positions: {
        data: [
          {
            type: 'positions',
            id: '1',
            method: 'update'
          }
        ]
      }
    },
  },
  included: [
    {
      id: '1',
      type: 'positions',
      attributes: { title: 'Software Engineer' },
      relationships: {
        department: {
          data: {
            id: '1',
            type: 'departments',
            method: 'destroy'
          }
        }
      }
    },
    {
      id: '1',
      type: 'departments',
      attributes: { name: 'Safety' }
    }
  ]
}
```

When creating nested records, we accept a `temp-id` - this is so the
client can match up the record they sent with the now-persisted record
in the response. Here we'll create an employee, position, and
department all in one go.

```ruby
{
  data: {
    type: 'employees',
    attributes: { name: 'Homer Simpson' },
    relationships: {
      positions: {
        data: [
          {
            type: 'positions',
            temp-id: 's0m3uu1d',
            method: 'create'
          }
        ]
      }
    },
  },
  included: [
    {
      temp-id: 's0m3uu1d',
      type: 'positions',
      attributes: { title: 'Software Engineer' },
      relationships: {
        department: {
          data: {
            temp-id: 'an0th3ruu1d'
            type: 'departments',
            method: 'create'
          }
        }
      }
    },
    {
      temp-id: 'an0th3ruu1d',
      type: 'departments',
      method: 'create'
    }
  ]
}
```

To accomodate this payload:

```ruby
class EmployeesController
  def create
    employee, success = jsonapi_create.to_a

    if success
      render_jsonapi(employee, scope: false)
    else
      render_errors_for(employee)
    end
  end

  def update
    employee, success = jsonapi_update.to_a

    if success
      render_jsonapi(employee, scope: false)
    else
      render_errors_for(employee)
    end
  end
end
```

And add a `model` to your corresponding `Resource`:

```ruby
class EmployeeResource < ApplicationResource
  # ... code ...
  model Employee
end
```

See the [tutorial on writes](https://gist.github.com/richmolj/c7f1adca75f614bb71b27f259ff3c37a#writes) for information on how to customize various write operations, whitelist parameters, nested validations, and more.

{::options parse_block_html="true" /}
<div style="height: 3rem" />
<div class='note info'>
###### Ensure _delete/_destroy are whitelisted
  <div class='note-content'>
  [strong_resources](https://github.com/jsonapi-suite/strong_resources) requires you to whitelist `_delete` and `_destroy`.
  This is pretty simple to do:

```ruby
strong_resource :employee do
  belongs_to :department, delete: true do
    has_many :goals, destroy: true
  end
end
```
  </div>
</div>
<div style="height: 20rem" />
