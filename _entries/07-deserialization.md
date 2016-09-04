---
sectionid: deserialization
sectionclass: h2
title: Deserialization
parent-id: writes
---

By default, Rails doesn't work too well with incoming JSON API payloads.
You can fix that with `deserialize_jsonapi!`:

```ruby
before_action :deserialize_jsonapi!, only: [:create, :update]
```

This will transform params from this:

```ruby
# POST /employees
{
  data: {
    type: 'employees',
    attributes: { name: 'Homer Simpson' }
  }
}
```

To this:

```ruby
{
  employee: {
    name: 'Homer Simpson'
  }
}
```

As if it were vanilla Rails. This will also transform any relationships
into an [accepts_nested_attributes_for](http://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html)-compatible payload:

```ruby
# POST /employees
{
  data: {
    type: 'employees',
    attributes: { name: 'Homer Simpson' },
    relationships: {
      department: {
        data: {
          type: 'departments',
          attributes: { name: 'Safety' }
        }
      }
    }
  }
}
```

Becomes:

```ruby
{
  employee: {
    name: 'Homer Simpson',
    department_attributes: {
      { name: 'Safety' }
    }
  }
}
```
