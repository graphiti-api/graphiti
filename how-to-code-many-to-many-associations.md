---
layout: page
---

Many-to-Many Associations
=========================

`has_and_belongs_to_many` are *possible*, but maybe not desirable
depending on your use case. Following the example from the [tutorial](/tutorial#many-to-many),
let's say an `Employee` has many `Team`s and a `Team` has many
`Employee`s. We could wire-up our `EmployeeResource` like so:

{% highlight ruby %}
has_and_belongs_to_many :teams,
  scope: -> { Team.all },
  foreign_key: { employee_teams: :employee_id },
  resource: TeamResource
{% endhighlight %}

The only difference here is the `foreign_key` - we're passing a hash
instead of a symbol. `employee_teams` is our join table, and
`employee_id` is the true foreign key.

This will work, and for simple many-to-many relationships you can move
on. But what if we want to add the property `primary`, a boolean, to the
`employee_teams` table?

As this is *metadata about the relationship* it should go on the `meta`
section of the corresponding [relationship object](http://jsonapi.org/format/#document-resource-object-relationships).
While supporting such an approach is on the JSONAPI Suite roadmap, many
clients do not currently support this per-object level of functionality.

For now, it might be best to simply expose the intermediate table to the
API. Using a client like
[JSORM](https://github.com/jsonapi-suite/jsorm), the overhead of this
approach is minimal.

<br />
<br />
