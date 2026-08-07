---
title: 'Relationships'
---

# Relationships {#relationships}

Resources rarely stand alone. This page covers how to connect them together for sideloading, sideposting, and links.

Resources can connect to other Resources via **relationships**.
Each relationship determines behavior for:

* Sideloading (load both Resources in a single request)
* Links (URL to lazy-load in separate request)
* Sideposting (save both in single request)

When connecting resources, you can imagine the logic similar to
`ActiveRecord`'s `.includes`:

```ruby
class PostResource < ApplicationResource
  has_many :comments
end

class CommentResource < ApplicationResource
  attribute :post_id, :integer, only: [:filterable]
  belongs_to :post
end

PostResource.all(include: 'comments')
# Under the hood:
# CommentResource.all(filter: { post_id: array_of_post_ids })

CommentResource.all(include: 'post')
# Under the hood:
# PostResource.all(filter: { id: array_of_comment_ids })
```

> Note the explicit `post_id` filter on `CommentResource`

## Deep Queries {#deep-queries}

A query that applies to a relationship is referred to as a **deep
query**. Use the dot-syntax to deep query:

`/employees?include=positions&filter[positions.title]=Manager`

`/employees?include=positions.department&filter[positions.department.name]=Engineering`

The above references the **relationship name**. For simplicity, you can
also pass the JSONAPI type in brackets:

`/employees?include=positions.department&filter[departments][name]=Engineering`

Sorting and pagination currently only support the JSONAPI type:

`/employees?include=positions.department&sort=departments.name`

`/employees?include=positions.department&page[departments][size]=10`

## Customizing Relationships {#customizing-relationships}

The default options you can override are:

```ruby
has_many :positions,
  foreign_key: :employee_id,
  primary_key: :id,
  resource: EmployeeResource,
  readable: true,
  writable: true,
  link: self.autolink, # default true
  single: false, # only allow this sideload when one employee
  always_include_resource_ids: self.always_include_resource_ids_by_default # default false
```

*note*: Setting `always_include_resource_ids: true` could result in 1+N queries (see [#167](https://github.com/graphiti-api/graphiti/issues/167#issuecomment-686866646))

To flip that default for every relationship at once, rather than repeating the option on each one, set it on `ApplicationResource`:

```ruby
class ApplicationResource < Graphiti::Resource
  self.always_include_resource_ids_by_default = true
end
```

Subclasses inherit the setting, and any relationship that passes `always_include_resource_ids` explicitly still wins over it. Mind the 1+N caveat above before turning this on app-wide.

### Conditional Relationships {#conditional-relationships}

Like attributes, the `readable` and `writable` flags on a relationship accept more than a boolean: pass a symbol, string, or proc and the relationship becomes conditional, evaluated per-request.

```ruby
class EmployeeResource < ApplicationResource
  has_many :salary_histories, readable: :admin?, writable: :admin?

  def admin?
    context.current_user.admin?
  end
end
```

When a readable guard returns `false`, the relationship is omitted from the serialized output and any attempt to sideload it via `?include=` is silently scrubbed from the request. When a writable guard returns `false`, sideposting to that relationship is rejected with an `unwritable_relationship` validation error.

Unlike attribute guards, relationship guards take no arguments. Include scrubbing happens before any records have been fetched, so there is no model to hand them. Base the decision on `context` alone.

The guard can live on either side of the relationship. Graphiti first looks for the method on the resource declaring the relationship. If it isn't defined there but is defined on the related resource, the related resource's method is used. Defining the guard on the related resource lets a single guard cover every relationship pointing at it:

```ruby
class SalaryHistoryResource < ApplicationResource
  # Any resource declaring a relationship to SalaryHistoryResource with
  # readable: :admin? will use this method, unless it defines its own.
  def admin?
    context.current_user.admin?
  end
end
```

> **Upgrading to 1.12:** relationship guards are new enforcement, not a new
> option. Before 1.12, a symbol, string, or proc passed to a relationship's
> `readable`/`writable` was accepted and silently treated as `true`. The guard
> was never called. Those guards now run. If your app already passes one of
> these, a relationship that has been serialized all along may start
> disappearing from responses.
>
> To list every guarded relationship in your app before deploying, run
> `bin/rails runner 'puts Graphiti.guarded_relationships'`.
>
> Apps using `schema.json` also get this for free: guarded relationships are
> flagged in the schema, and the schema check reports them as
> `became guarded`.

### Customizing Scope {#customizing-scope}

Use `params` to change the query parameters that will be passed to the
associated Resource:

```ruby
has_many :active_positions, resource: PositionResource do
  params do |hash, employees|
    hash[:filter][:active] = true
  end
end

# Would cause the underlying query:
#
# PositionResource.all({
#   filter: {
#     employee_id: array_of_employee_ids
#     active: true
#   }
# })
```

If there is no existing AR association for this we would also need to make it a getter/setter on the model.

```ruby
# app/models/position.rb
attr_accessor :active_positions
```

### Customizing Assignment {#customizing-assignment}

Once we've fetched primary data and its relationship (e.g. we have an
`employees` array and `positions` array), we need to associate these
objects:

```ruby
employees.each do |e|
  e.positions = positions.select { |p| p.employee_id == e.id }
end
```

Occasionally this logic will be non-standard or more complex. Use
`assign_each` to customize, returning all relevant children for the
given parent:

```ruby
has_many :positions do
  assign_each do |employee, positions|
    positions.select { |p| p.belongs_to?(employee) }
  end
end
```

Or if all else fails, use `#assign` to control all the logic:

```ruby
has_many :positions do
  assign do |employees, positions|
    employees.each do |employee|
      positions.select { |p| p.belongs_to?(employee) }
    end
  end
end
```

**Note**: ActiveRecord will sometimes cause unexpected queries when
assigning. If you're overriding `#assign`, make sure to keep an eye on this. If using `#assign_each`, you're fine because the adapter will take
care of this for you.

## has_many {#has-many}

```ruby
has_many :positions
```

Defaults to these common options:

```ruby
has_many :positions,
  foreign_key: :employee_id,
  primary_key: :id,
  always_include_resource_ids: false,
  resource: PositionResource
```

Which would cause the following query when sideloading:

```ruby
PositionResource.all({ filter: { employee_id => employee_ids } })
```

This means **we need to make sure that filter is supported**:

```ruby
class PositionResource < ApplicationResource
  attribute :employee_id, :integer, only: [:filterable]
  # ... code ...
end
```

Once we've resolved `employees` and `positions` the resulting objects
would be associated with logic similar to:

```ruby
employees.each do |e|
  e.positions = positions.select { |p| p.employee_id == e.id }
end
```

And generate a Link:

`/positions?filter[employee_id]=1,2,3`

## belongs_to {#belongs-to}

```ruby
belongs_to :employee
```

Defaults to these common options:

```ruby
belongs_to :employee,
  foreign_key: :employee_id,
  primary_key: :id,
  always_include_resource_ids: false,
  resource: EmployeeResource
```

Which would cause the following query when sideloading:

```ruby
EmployeeResource.all({ filter: { id => position_ids } })
```

And assign the resulting objects with logic similar to:

```ruby
positions.each do |p|
  p.employee = employees.find { |e| p.employee_id == e.id }
end
```

And generate a Link:

`/employees?filter[id]=1,2,3`

## has_one {#has-one}

`has_one` works exactly like `has_many`, but only one record will be
returned. When sideloading this will be a single element, much like
`belongs_to`.

There is one small caveat: Links always point to an `index` action, so we can apply filters. That means following *`has_one` Link will lead to
an array*, and you should select the first record.

### Faux has_one {#faux-has-one}

A "Faux Has One" occurs when there is more than one record of
associated data, but we only want to return the *first* record in that
array. Consider this `ActiveRecord` relationship:

```ruby
# app/models/employee.rb
has_many :positions
has_one :current_position, -> { where(created_at: :desc) }, class_name: 'Position'

Employee.includes('current_position').to_a

# SELECT * FROM employees
# SELECT * FROM positions WHERE employee_id IN (?) ORDER BY created_at DESC
```

When we eager load, *more than one Position is returned from the
database query*. Assigning only the first record and dropping the rest
occurs in ruby, not the database query.

The same thing happens in Graphiti:

```ruby
# app/resources/employee_resource.rb
has_many :positions
has_one :current_position, resource: PositionResource do
  params do |hash|
    hash[:sort] = '-created_at'
  end
end

EmployeeResource.all(include: 'current_position')
# PositionResource.all({
#   filter: { employee_id: employee_ids },
#   sort: '-created_at'
# })
```

Though everything works as expected, a large number of Position records
can incur a performance penalty (as we'd be instantiating a large number
of ActiveRecord objects).

For this reason, you are encouraged to model Faux Has One's in such a
way that the underlying database query only returns the relevant single
record. Imagine if we had a `historical_index` column on `positions`, where a value of `1` meant "most recent":

```ruby
# app/models/employee.rb
has_many :positions
has_one :current_position, -> { where(historical_index: 1) }, class_name: 'Position'

Employee.includes('current_position').to_a

# SELECT * FROM employees
# SELECT * FROM positions WHERE employee_id IN (?) AND historical_index = 1
```

We've ensured the *query itself* only returns a single record.
Optimizing a Graphiti API is the same as optimizing queries.

## many_to_many {#many-to-many}

> This relationship is specific to relational databases that use a "join
> table" between two tables.

Though you can make this work for other ORMs/clients, it's easiest to
explain by focusing on `ActiveRecord`.

First, **you must use [has_many :through](https://guides.rubyonrails.org/association_basics.html#the-has-many-through-association) and not has_and_belongs_to_many**:

```ruby
class Employee < ApplicationRecord
  has_many :team_memberships
  has_many :teams, through: :team_memberships
end

class TeamMembership < ApplicationRecord
  belongs_to :employee
  belongs_to :team
end

class Team < ApplicationRecord
  has_many :team_memberships
  has_many :employees, through: :team_memberships
end
```

You can always expose `team_memberships` to your API - particularly
useful if that table holds metadata about the relationship.

Other times, however, clients of the API should not have knowledge of
this implementation detail. In these cases, use `many_to_many`:

```ruby
class EmployeeResource < ApplicationResource
  many_to_many :teams
end
# Generates the Link
# /teams?filter[employee_id]=1,2,3

class TeamResource < ApplicationResource
  many_to_many :employees
end
# Generates the Link
# /teams?filter[team_id]=1,2,3
```

The `many_to_many` call will automatically add a Filter to the associated resource. The logic for that filter, in the case of `ActiveRecord`:

```ruby
# app/resources/employee_resource.rb

filter :team_id, :integer do
  eq do |scope, value|
    scope
      .includes(:team_memberships)
      .where(team_memberships: { team_id: value }
  end
end
```

To customize the foreign key, you will need to specify a hash rather
than a symbol. The hash key is the relationship name, so the above is
equivalent to

```ruby
# app/resources/employee_resource.rb

many_to_many :teams, foreign_key: { team_memberships: :team_id }
```

If using ActiveRecord, and the API relationship name does not match your
Model relationship name, use `:as` to specify the model relationship
that should be used to derive the query:

```ruby
# The API relationship is "teams", ActiveRecord has "groups"
many_to_many :teams, as: :groups
```

## polymorphic_belongs_to {#polymorphic-belongs-to}

With polymorphic associations, a Resource can belong to more than one other Resource, on a single association. Though these relationships are not specific to `ActiveRecord`, we'll use `ActiveRecord` conventions to describe the use case.

Given the following [polymorphic ActiveRecords](https://guides.rubyonrails.org/association_basics.html#polymorphic-associations):

```ruby
class Note < ApplicationRecord
  belongs_to :notable, polymorphic: true
end

class Employee < ApplicationRecord
  has_many :notes, as: :notable
end

class Department < ApplicationRecord
  has_many :notes, as: :notable
end

class Team < ApplicationRecord
  has_many :notes, as: :notable
end
```

By `ActiveRecord` convention, the `notes` table would have columns `notable_id` and `notable_type`.

Graphiti has the same concept. In this case we would group all the notes
by a given `notable_type`, and follow a different `belongs_to`
association for each group:

```ruby
# app/resources/note_resource.rb
polymorphic_belongs_to :notable do
  group_by(:notable_type) do
    on(:Employee)
    on(:Department)
    on(:Team)
  end
end
```

The `on` DSL is shorthand for a `belongs_to` relationship that accepts
all the usual options and customizations:

```ruby
on(:Employee).belongs_to :employee,
  resource: EmployeeResource
  # ... etc ...
```

In other words: group all Notes by `notable_type`, and for all that have the value of `"Employee"` use the `belongs_to :employee` relationship
for further querying.

## polymorphic_has_many {#polymorphic-has-many}

Continuing from the prior section, the corresponding association of a
`polymorphic_belongs_to` is a `polymorphic_has_many`:

```ruby
class EmployeeResource < ApplicationResource
  polymorphic_has_many :notes, as: :notable
end
```

Predictably, this causes the query:

```ruby
NoteResource.all({
  filter: {
    notable_type: 'Employee',
    notable_id: employee_ids
  }
})
```

And the Link

`/notes?filter[notable_id]=1,2,3&filter[notable_type]=Employee`

Which means the following filters are required:

```ruby
class NoteResource < ApplicationResource
  attribute :notable_id, :integer, only: [:filterable]
  attribute :notable_type, :string, only: [:filterable]
  # ... code ...
end
```
