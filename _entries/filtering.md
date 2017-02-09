---
sectionid: filtering
sectionclass: h2
title: Filtering
parent-id: reads
number: 7
---

Use `allow_filter` in your resource to whitelist filters:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  allow_filter :name
end
```

If a request
comes in for a filter that is not whitelisted, a
`JsonapiCompliable::Errors::BadFilter` error will be raised.

Customize the filter by passing a block:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  allow_filter :name_prefix do |scope, value|
    scope.where(["name LIKE ?", "#{value}%"])
  end
end
```

Filters can be conditional/guarded as well:

```ruby
# app/resources/employee_resource.rb
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  allow_filter :name, if: :admin?
end

# app/controllers/application_controller.rb
class EmployeesController < ApplicationController
  jsonapi resource: EmployeeResource

  def index
    render_jsonapi(Employee.all)
  end

  def admin?
    current_user.admin?
  end
end
```

In this example, the controller's `#admin?` method would be called. If
it returned false, we would allow filtering on this attribute, otherwise
we would raise an error.
