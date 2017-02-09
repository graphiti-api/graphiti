---
sectionid: sideloading-activerecord
sectionclass: h4
title: ActiveRecord
parent-id: sideloading
number: 13
---

Similar to Resources, Sideloads can use the Adapter to DRY up this code. Using the `ActiveRecord` adapter, the following code is equivalent:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  belongs_to :department,
    foreign_key: :department_id,
    scope: -> { Department.all },
    resource: DepartmentResource
end

class DepartmentResource < JsonapiCompliable::Resource
  type :departments
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  has_many :goals,
    foreign_key: :department_id,
    scope: -> { Goal.all },
    resource: GoalResource
end
```

We passed:

* `foreign_key` - Explicit, to avoid ActiveRecord reflection magic.
* `primary_key` (Optional) - Defaults to `id`
* `scope` - The 'base scope' for DepartmentResource
* `resource` - Which will handle filtering/sorting/etc of this
  relationship. It will likely be re-used for the `/departments`
endpoint.
