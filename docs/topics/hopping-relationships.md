---
title: 'Hopping Relationships'
---

# Hopping Relationships
> [See the code](https://github.com/graphiti-api/employee_directory/commit/b187127d60ea67ef4c2a326721caeaad21ed7ec9)

Our [sample application](https://github.com/graphiti-api/employee_directory)
has the setup `Employee > Position > Department`, where one of the positions is the `current_position`. What if we wanted to change this to `Employee > Department`, hiding everything about positions
under-the-hood?

Let's start by saying an `Employee` has many `Department`s. Here's the
spec:

```ruby
describe 'sideloading' do
  describe 'departments' do
    let!(:employee) { create(:employee) }
    let!(:position1) do
      create :position,
        historical_index: 2,
        employee: employee,
        department: department1
    end
    let!(:position2) do
      create :position,
        historical_index: 1,
        employee: employee,
        department: department2
    end
    let!(:department1) { create(:department) }
    let!(:department2) { create(:department) }

    before do
      params[:include] = 'departments'
    end

    it 'finds the departments for all positions' do
      render
      sl = d[0].sideload(:departments)
      expect(sl.map(&:id)).to eq([department1.id, department2.id])
      expect(sl.map(&:jsonapi_type).uniq).to eq(['departments'])
    end
  end
end
```

Start by defining the association:

```ruby
has_many :departments
```

And you'll get this error:

```error
Graphiti::Errors::AttributeError:
  DepartmentResource: Tried to filter on attribute :employee_id, but could not find an attribute with that name.
```

Which makes sense - if this is a `has_many` association, we'd expect DepartmentResource to filter by `employee_id`. Though in our case we
don't have that as a foreign key, we can still implement the
`employee_id` filter:

```ruby
filter :employee_id, :integer, only: [:eq] do
  eq do |scope, value|
    scope.joins(:positions).merge(Position.where(employee_id: value))
  end
end
```

In order to find `Department`s by an `employee_id`, we need to join the `positions` table which has the `employee_id` column.

We now get this error:

```error
NoMethodError:
  undefined method `employee_id' for #<Department:0x00007fa6f330f768>
```

Let's say our URL is `/employees?include=departments`. We've fetched all the `Employee`s and all the `Department`s, now we need to associate each `Department` with its relevant `Employee`. Normally we'd do that by looking at the `employee_id` foreign key on `Department`, but this
scenario has non-standard logic. Let's tell Graphiti how to select
relevant `Department`s for a given `Employee`:

```ruby
has_many :departments do
  assign_each do |employee, departments|
    departments.select do |d|
      employee_ids = d.positions.map(&:employee_id).flatten
      employee.id.in?(employee_ids)
    end
  end
end
```

There's one final step - because we're assigning a department to an
employee, we have to make sure that accessor exists:

```ruby
# app/models/employee.rb
attr_accessor :department
```


And that's it! Our test now passes.

There's a little bit of sleight-of-hand above though. Our filter joins
to the `positions` table, and our assignment iterates over departments and calls `department.positions`. **If we don't eager load, we'll cause
an N+!**!

There are two solutions to this. The first is to simple change `.joins` to `.eager_load`:

```ruby
scope.eager_load(:positions).merge(Position.where(employee_id: value))
```

This ensures that not only are we joining on the `positions` table, we'll eagler load the `positions` *relationship* and avoid the N+1.

If you're a stickler, though, you may have a nitpick. For one, if
we're hitting `/departments?filter[employee_id]` directly there is no need to eager load `positions` because we're never associating to an `Employee`. We're paying a performance penalty when we don't have to.

OK, let's keep our filter `.joins`. We just have to tell Graphiti to switch it to `.eager_load` when sideloading through `EmployeeResource`:

```ruby
has_many :departments do
  # ... code ...

  pre_load do |proxy, employees|
    proxy.scope.object = proxy.scope.object.eager_load(:positions)
  end
end
```

The `pre_load` hook fires after we've built up the scope, but before we resolve it (before actually firing the query). It yields a `proxy`
object that we can modify - here we're modifying the scope to eager load
positions.

It's up to you if you care about this scenario - you may want to start
with `.eager_load` and only embrace to the extra work of `pre_load` when
you really need it.

The trick to these customizations is to think in Links. Resources
connect to each other with URLs - what would the query parameters of the
URL be? In this case, `filter?[employee_id]=123`. After that, we just
have to define how to associate relevant objects. Even with complex
associations hopping several levels, the same logic applies.

See the final code [here](https://github.com/graphiti-api/employee_directory/commit/b187127d60ea67ef4c2a326721caeaad21ed7ec9).
