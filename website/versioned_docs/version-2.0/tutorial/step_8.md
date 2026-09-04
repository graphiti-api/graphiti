---
title: 'Step 8'
---

### Step 8: Polymorphic Relationships

> [View the Diff](https://github.com/graphiti-api/employee_directory/compare/step_7_many_to_many...step_8_polymorphic_belongs_to)

Let's introduce the concept of a Note. A Note can belong to a
Department, an Employee, or a Team. For this, we'll need to introduce
the concept of [polymorphism](https://guides.rubyonrails.org/association_basics.html#polymorphic-associations).

<table class="table table-small text-center">
  <thead>
    <tr>
      <th class="text-center">id</th>
      <th class="text-center">notable_id</th>
      <th class="text-center">notable_type</th>
      <th class="text-center">body</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>1</td>
      <td>Employee</td>
      <td>A Sample Note!</td>
    </tr>
    <tr>
      <td>2</td>
      <td>1</td>
      <td>Department</td>
      <td>Another Sample Note!</td>
    </tr>
    <tr>
      <td>3</td>
      <td>1</td>
      <td>Team</td>
      <td>A Third Sample Note!</td>
    </tr>
  </tbody>
</table>

### The Rails Stuff 🚂

```bash
$ rails generate model Note notable:references{polymorphic}:index
$ bin/rails db:migrate
```

Make sure to add the corresponding model relationships:

```ruby
# app/models/employee.rb
has_many :notes, as: :notable
# app/models/team.rb
has_many :notes, as: :notable
# app/models/department.rb
has_many :notes, as: :notable

# app/models/note.rb
belongs_to :notable, polymorphic: true
```

Finally, make sure to edit your seed file - check out the [diff](https://github.com/graphiti-api/employee_directory/compare/step_7_many_to_many...step_8_polymorphic_belongs_to) to see the necessary adjustments.

### The Graphiti Stuff 🎨

```bash
$ bin/rails g graphiti:resource Note body:string
```

Let's create our `NoteResource`:

```ruby
class NoteResource < ApplicationResource
  attribute :body, :string

  filter :notable_id, :integer
  filter :notable_type, :string, allow: %w(Employee Department Team)

  polymorphic_belongs_to :notable do
    group_by(:notable_type) do
      on(:Employee)
      on(:Team)
      on(:Department)
    end
  end
end
```

And corresponding associations:

```ruby
# app/resources/employee_resource.rb
polymorphic_has_many :notes, as: :notable
# app/resources/team_resource.rb
polymorphic_has_many :notes, as: :notable
# app/resources/department_resource.rb
polymorphic_has_many :notes, as: :notable
```

#### Digging Deeper 🧐

When defining a polymorphic relationship for our API, we're saying "grab
all the parent records, group them by a `type` column, and execute different queries for each type". This way records with `notable_type ==
'Employee'` can hit the `employees` table, but records with `notable_type == 'Department'` could in theory load from a different API
altogether.

Each of the `on` lines defines a new `belongs_to` association. That
means you can customize just like always:

```ruby
on(:Team).belongs_to :team, resource: SomeCustomTeamResource do
  # assign {}
  # link {}
  # ... etc ...
end
```


  <h2 id="next">
    <a href="/tutorial/step_9">
      NEXT - 
      <small>Step 9: Polymorphic Resources</small>
      &raquo;
    </a>
  </h2>
