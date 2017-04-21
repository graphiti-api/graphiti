---
sectionid: writes
sectionclass: h1
title: Writes
is-parent: true
number: 16
---

Basic writes are very similar to vanilla Rails. Since we allow nested
creation of non-ActiveRecord objects the syntax is slightly different:

```ruby
class EmployeesController < ApplicationController
  jsonapi resource: EmployeeResource

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

To enable writes, make sure your resources know about a corresponding
`Model`:

```ruby
class EmployeeResource < ApplicationResource
  type :employees
  model Employee
end
```
