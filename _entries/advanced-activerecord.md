---
sectionid: advanced-activerecord
sectionclass: h4
title: Advanced ActiveRecord
parent-id: sideloading
number: 14
---

In addition to `belongs_to` and `has_many`, we have
`has_and_belongs_to_many`. Everything is the same, but the foreign key
must be a composite key that includes the `through` table. Given these
models:

```ruby
class Employee < ActiveRecord::Base
  has_many :taggings
  has_many :tags, through: :taggings
end

class Tagging < ActiveRecord::Base
  belongs_to :employee
  belongs_to :tag
end

class Tag < ActiveRecord::Base
  has_many :taggings
  has_many :employees, through: :taggings
end
```

We would have this macro in our resource:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  has_and_belongs_to_many :tags,
    foreign_key: { taggings: :employee_id },
    scope: -> { Tag.all },
    resource: TagResource
end
```

Finally, we have **polymorphic** relationships. Let's say an `Employee`
has a `Workspace`, which can be either an `Office` or a `Cubicle`. Given
these ActiveRecord models:

```ruby
class Employee < ActiveRecord::Base
  # we have workspace_type and workspace_id columns
  belongs_to :workspace, polymorphic: true
end

class Office < ActiveRecord::Base
  has_many :employees, as: :workspace
end

class Cubicle < ActiveRecord::Base
  has_many :employees, as: :workspace
end
```

We'd have this macro in our resource:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  polymorphic_belongs_to :workspace,
    group_by: proc { |employee| employee.workspace_type },
    groups: {
      'Cubicle' => {
        foreign_key: :workspace_id,
        resource: WorkspaceResource,
        scope: -> { Cubicle.all }
      },
      'Office' => {
        foreign_key: :workspace_id,
        resource: WorkspaceResource,
        scope: -> { Office.all }
      }
    }
end
```

In the above code, we group employees by `workspace_type`. When it's a
`Cubicle`, we use a different configuration than when it's an `Office`.
Note: both configurations use the same resource in this example - we're
starting with a different 'base scope', but after that everything is the
same!
