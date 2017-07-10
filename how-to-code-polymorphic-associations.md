---
layout: page
---

Polymorphic Associations
=========================

Let's say an `Employee` belongs to a `Workspace`. `Workspace`s have
different `type`s - `HomeOffice`, `Office`, `CoworkingSpace`, etc.

Assuming we've already set up our database, let's add the associations
to our `Model`s:

```ruby
# app/models/employee.rb
belongs_to :workspace, polymorphic: true
```

```ruby
# app/models/workspace.rb
has_many :employees, as: :workspace
```

Now we need to wire-up our resource. Usually you'd see something like
`has_many` with a few options. But here, we may actually want to change
our configuration based on `Workspace#type` - maybe each type of data is
stored in a separate table, for instance.

We want to pass the same configuration, but on a type-by-type basis. In
other words, we need to group workspaces and define how to associate
each group:

```ruby
# app/resources/employee_resource.rb
polymorphic_belongs_to :workspace,
  group_by: :workspace_type,
  groups: {
    'Office' => {
      scope: -> { Office.all },
      resource: OfficeResource,
      foreign_key: :workspace_id
    },
    'HomeOffice' => {
      scope: -> { HomeOffice.all },
      resource: HomeOfficeResource,
      foreign_key: :workspace_id
    }
  }
```

Let's say our API was returning 10 `Employees`, sideloading their
corresponding `Workspace`. The underlying code would:

* Fetch the employees
* Group the employees by the given key: `employees.group_by { |e|
  e.workspace_type }`
* Use the `Office` configuration for all `Employee`s where
  `workspace_type` is `Office`, and use the `HomeOffice` configuration
for all `Employee`s where `workspace_type` is `HomeOffice`.

<br />
<br />

{% include highlight.html %}
