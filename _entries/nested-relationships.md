---
sectionid: nested-relationships
sectionclass: h2
title: Nested Relationships
number: 16
parent-id: jsonapi-plus
---

We've already mentioned nested relationships, but this is actually not
currently part of the core JSON API spec. We accept PUT or POST
payloads with nested attributes, including `_delete` (disassociate) and
`_destroy` attributes:

```ruby
{
  type: 'employees',
  attributes: { name: 'Homer Simpson' },
  relationships: {
    department: {
      data: {
        type: 'departments',
        id: 1,
        relationships: {
          goals: {
            data: {
              type: 'goals',
              id: 2,
              attributes: { _delete: true }
            }
          }
        }
      }
    }
  }
}
```

To honor this API we need to customize `accepts_nested_attributes_for`.
Since we're overring ActiveRecord, we require you to explicitly include
this module:

```ruby
class Employee < ApplicationRecord
  include NestedAttributeReassignable
end
```

And instead of using `accepts_nested_attributes_for`, use
`reassignable_nested_attributes_for`. Otherwise, everything is the same
and will 'just work'.

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

