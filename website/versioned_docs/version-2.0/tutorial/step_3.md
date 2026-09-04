---
title: 'Step 3'
---

### Step 3: Belongs To

> [View the Diff](https://github.com/graphiti-api/employee_directory/compare/step_2_positions...step_3_departments)

We'll be adding the database table `departments`:

<table class="table table-small text-center">
  <thead>
    <tr>
      <th class="text-center">id</th>
      <th class="text-center">name</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>Engineering</td>
    </tr>
    <tr>
      <td>2</td>
      <td>Safety</td>
    </tr>
    <tr>
      <td>3</td>
      <td>QA</td>
    </tr>
  </tbody>
</table>

We'll also be adding a `department_id:integer` foreign key column to the `positions` table.

### The Rails Stuff 🚂

Generate the `Department` model:

```bash
$ bin/rails g model Department name:string
```

To add the foreign key to `positions`:

```bash
$ bin/rails g migration add_department_id_to_positions
```

```ruby
class AddDepartmentIdToPositions < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :positions, :departments
  end
end
```

Update the database:

```bash
$ bin/rails db:migrate
```

Update our seed file:

```ruby
[Employee, Position, Department].each(&:delete_all)

engineering = Department.create! name: 'Engineering'
safety = Department.create! name: 'Safety'
qa = Department.create! name: 'QA'
departments = [engineering, safety, qa]

100.times do
  employee = Employee.create! first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    age: rand(20..80)

  (1..2).each do |i|
    employee.positions.create! title: Faker::Job.title,
      historical_index: i,
      active: i == 1,
      department: departments.sample
  end
end
```

Make sure to update `spec/factories/departments.rb` with randomized
data. Then, since this is also a required relationship, update
`spec/factories/positions.rb` to always seed a department when we ask to
create a position:

```ruby
factory :position do
  employee
  department

  # ... code ...
end
```

### The Graphiti Stuff 🎨

You should be used to this by now:

```bash
bin/rails g graphiti:resource Department name:string
```

Add the association:

```ruby
# app/resources/position_resource.rb
belongs_to :department
```

And review the end of [Step 2](/tutorial/step_2) to get all your specs
passing (add the department to the request payload). Practice makes perfect!

#### Digging Deeper 🧐

We didn't need a filter like we did in step two. That's
because the primary key connecting the Resources is `id` by
default. In other words, the Link would be something like:

```bash
/departments?filter[id]=1
```

Which we get out-of-the-📦

But remember, you can customize these relationships just like the
previous `has_many` section.


  <h2 id="next">
    <a href="/tutorial/step_4">
      NEXT - 
      <small>Step 4: Customizing Queries</small>
      &raquo;
    </a>
  </h2>
