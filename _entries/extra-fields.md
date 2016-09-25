---
sectionid: extra-fields
sectionclass: h2
title: Extra Fields
number: 17
parent-id: jsonapi-plus
---

We've already covered JSON API sparse fieldsets. But what about the
opposite? Sometimes you have a field that should only be in the response
when specifically requested. Maybe this extra field is computationally
expensive and you don't want to pay the penalty for every request. Maybe
it's a UI-specific value you just need to share between your website and
mobile app.

Enter `extra_fields`. We support URLs with the parameter `extra_fields`
with the same signature as `fields`:

* `/api/employees?extra_fields[people]=net_worth`

Now whitelist the field in your controller, and add to your serializer:

```ruby
# app/controllers/employees_controller.rb
jsonapi do
  extra_field :net_worth
end

# app/serializers/employee_serializer.rb
class EmployeeSerializer < ApplicationSerializer
  extra_attribute :net_worth
end
```

As this may require traversing relationships to derive the value, you
may want to eager load some data when the extra field is requested:

```ruby
jsonapi do
  extra_field(people: [:net_worth]) do |scope|
    scope.includes(:assets)
  end
end
```

Finally, a special `allow_x?` method is overrideable in your serializer.
This is if additional conditionals must fire aside from the field being
requested:

```ruby
def allow_net_worth?
  return false unless current_user.admin?
  super
end
```
