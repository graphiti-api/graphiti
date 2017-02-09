---
sectionid: sideloading-introduction
sectionclass: h3
title: Introduction
parent-id: sideloading
is-parent: true
number: 12
---

JSONAPI has the `?include` query parameter ([documentation](http://jsonapi.org/format/#fetching-includes)), which is used to 'sideload'
relationships. We use Resource objects for our main entities, and
**Sideload** objects for the relationships.

Similar to a Resource, a Sideload defines how we're going to build up a
scope. But instead of defining pagination, sorting, etc, we need to
define:

* How to build a base scope for this relationship from the main
entities.
* How to assign the results of this sideload to the main entities.

In code, we do this through the `scope` and `assign` lambdas:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  allow_sideload :department, resource: DepartmentResource do
    # We've resolved the employee scope to an array of Employee objects
    # Now we need to specify how to get departments for those employees.
    scope do |employees|
      Department.where(id: employees.map(&:department_id))
    end

    # Now we've resolved BOTH the Employee and Department scopes
    # Assign relevant department to each employee
    assign do |employees, departments|
      employees.each do |e|
        e.department = departments.find { |d| d.id == e.department_id }
      end
    end
  end
end
```

**Note:** - `scope` must return a chainable scope object - it's going to be passed
to DepartmentResource so that we can sort/filter/etc our relationships
as well.

Finally, sideloads are nested. Let's say each `Department` has many
`Goal`s. We want to load employees, their departments, and the goals for
those departments:

```
/employees?include=department.goals
```

As long as the `DepartmentResource` has a `goals` sideload, this query
will work. However, we may want to 'whitelist' only a subset of possible
sideloads, to accomodate load or security issues:

```ruby
class EmployeesController < ApplicationController
  jsonapi resource: EmployeeResource do
    sideload_whitelist({
      index: :department,
      show: { department: :goals }
    })
  end
end
```
