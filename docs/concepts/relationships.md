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
  resource_ids: false
```

`resource_ids` is the one whose default depends on the relationship type:

| type | renders resource ids by default |
|---|---|
| `belongs_to` | yes, when its foreign key already holds the related id |
| `has_one` | no |
| `has_many` | no |
| `many_to_many` | no |
| `polymorphic_belongs_to` | no |

`belongs_to` renders them so a client can see which record a relationship points at without following the link:

```json
"employee": {
  "data": { "type": "employees", "id": "1" },
  "links": { "related": "/employees?filter[id]=1" }
}
```

That costs nothing, because the id is already on the parent as its foreign key.

No other relationship type has a free source for its ids. A collection accepts `resource_ids: true`, but that reads the association on every render of every parent record, whether or not the request wants the relationship. That is the N+1 from [#167](https://github.com/graphiti-api/graphiti/issues/167#issuecomment-686866646) on every response. Leave collections off and let clients `?include=` them.

Not every `belongs_to` can use its foreign key. A `scope` or `params` block or a `base_scope` can filter out the record the key points at, a polymorphic target's type varies per record while rendered ids carry one type for the whole relationship, a remote resource has no local key to read, and a custom `primary_key` points the relationship at some other column. Those load the association instead, so they stay off by default too.

<details>
<summary>Which `belongs_to` declarations render resource ids, and which do not</summary>

```ruby
# yes. employee_id is the employee's id, so the payload already has it
belongs_to :employee

# no. nothing renders at all, ids included
belongs_to :employee, readable: false

# no. employee_id holds a name, not the related id
belongs_to :employee, primary_key: :first_name

# no. the base scope can exclude the employee the key points at, and
# graphiti cannot know whether it does without running it
belongs_to :employee, base_scope: -> { Employee.all }

# no. a remote resource has no local foreign key to read
belongs_to :employee, remote: "http://foo.com/employees"

# no. the record's own class decides its type, so the key gives an id
# with no type to pair it with
belongs_to :employee, resource: CreditCardResource

# no. the scope can exclude the employee the key points at, and graphiti
# cannot know whether it does without running it
belongs_to :employee do
  scope { |ids| {type: :employees, conditions: {id: ids}} }
end

# no. same, a params filter can exclude the employee the key points at
belongs_to :employee do
  params { |hash, positions| hash[:filter][:active] = true }
end

# no. credit_card_type is local, but rendered ids carry one type for the
# whole relationship and this one's varies per record
polymorphic_belongs_to :credit_card do
  group_by(:credit_card_type) do
    on(:Visa).belongs_to :visa, resource: VisaResource
  end
end
```

Watch for the `scope`, `params` and `base_scope` cases. Nothing about those declarations looks like it concerns resource ids, so adding a scope block to filter a relationship also stops its ids from rendering.

If you keep a `schema.json`, the schema check catches that. A relationship that renders resource ids is marked `linkage: true`, and one that stops rendering them is reported as a breaking change. Gaining them is additive and passes.

To render ids anyway, opt in on the relationship and accept the query:

```ruby
belongs_to :employee, resource_ids: true do
  scope { |ids| {type: :employees, conditions: {id: ids}} }
end
```

Know what that buys for the `scope`, `params` and `base_scope` cases. Rendering reads the association off the model, which does not apply the block, so if the block narrows what sideloading returns, the ids will disagree with it. Opting in there says you know the two agree. A `primary_key`, polymorphic or remote relationship does resolve to the right id this way.

</details>

### belongs_to_resource_ids_by_default {#belongs-to-resource-ids}

To change how far a `belongs_to` goes, across a whole API, set it on the resource everything inherits from:

```ruby
class ApplicationResource < Graphiti::Resource
  self.belongs_to_resource_ids_by_default = :foreign_key
end
```

| | |
|---|---|
| `:foreign_key` | Default. Render resource ids wherever the foreign key already holds the related id, and never run an extra query. |
| `:always` | Render them for every `belongs_to`, loading the association when the foreign key cannot answer. A query per record, per relationship, on every render. |
| `:never` | Render none. This is the 1.x payload. |

Subclasses inherit it, and a relationship passing `resource_ids` explicitly still wins.

All three describe requests that do not include the relationship. A relationship the request does include renders its ids whatever this is set to, `:never` included, because the records are already loaded and sitting in `included`.

Before flipping the setting, [`bin/rake graphiti:audit`](/topics/debugging#graphiti-audit) reports how every relationship renders resource ids today and which would start loading the association.

#### What a client sees {#relationship-payload-shapes}

A client never has to work out which rule applied. The relationship object says what it knows:

```json
"employee": { "data": { "type": "employees", "id": "1" } }   // here is the id
"employee": { "links": { "related": "..." } }                 // fetch it yourself
"employee": { "meta": { "included": false } }                 // neither
```

The last shape appears only when a relationship has no ids **and** no link, which usually means `link: false`. It is not a general "was this sideloaded" flag. Relationships are autolinked by default, so the link shape is the one you normally see.

The setting covers `belongs_to` and `polymorphic_belongs_to`, and no collection, deliberately. An API-wide `:always` on collections would be the N+1 from [#167](https://github.com/graphiti-api/graphiti/issues/167#issuecomment-686866646) applied everywhere at once.

`:always` renders ids by loading the association, so a relationship naming a method the model does not have raises on every render once you set it.

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
  resource_ids: false,
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
  resource_ids: true,
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
