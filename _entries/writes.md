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

All writes run in an a transaction (by default, an ActiveRecord
transaction) and will be rolled back upon error. This can be customized
as well:

```ruby
# Default Implementation
def transaction(model_class)
  model_class.transaction do
    yield
  end
end
```

Any object implementing ActiveModel::Validations `#errors` will be
respected. So, if we had:

```ruby
class Employee < ApplicationRecord
  validates :first_name, presence: true
end
```

And no `first_name` attribute is sent, the API will response with
validation errors and the transaction will be rolled back.
