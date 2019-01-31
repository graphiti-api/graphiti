---
layout: page
---

<div markdown="1" class="toc col-md-3">
Resources
==========

* 1 [Overview](#overview)
* 2 [Attributes](#attributes)
  * [Limiting Behavior](#limiting-behavior)
  * [Default Behavior](#default-behavior)
  * [Customizing Display](#customizing-display)
    * [Explicit Serializers](#explicit-serializers)
  * [Types](#types)
* 3 [Querying](#querying)
  * [Query Interface](#query-interface)
  * [Composing with Scopes](#composing-with-scopes)
  * [`#base_scope`](#basescope)
  * [Sort](#sort)
    * [Sort Options](#sort-options)
  * [Filter](#filter)
    * [Filter Options](#filter-options)
    * [Boolean Filter](#boolean-filter)
    * [Hash Filter](#hash-filter)
    * [Escaping Values](#escaping-values)
  * [Statistics](#statistics)
  * [`#resolve`](#resolve)
* 4 [Configuration](#configuration)
  * [Polymorphic Resources](#polymorphic-resources)
* 5 [Relationships](#relationships)
  * [Deep Queries](#deep-queries)
  * [Customizing Relationships](#customizing-relationships)
  * [has_many](#hasmany)
  * [belongs_to](#belongsto)
  * [has_one](#hasone)
  * [many_to_many](#manytomany)
  * [polymorphic_belongs_to](#polymorphicbelongsto)
  * [polymorphic_has_many](#polymorphichasmany)
* 6 [Generators](#generators)
* 7 [Persisting](#persisting)
  * [Side Effects](#side-effects)
  * [Sideposting](#sideposting)
    * [Create](#create)
    * [Expanded Example](#expanded-example)
  * [Validation Errors](#validation-errors)
* 8 [Context](#context)
* 9 Adapters
</div>

<div markdown="1" class="col-md-8">

## 1 Overview

The same way a `Model` is an abstraction around a database table, a
`Resource` is an abstraction around an API endpoint. It holds logic for
***querying***, ***persisting***, and ***serializing*** data.

> For a condensed view of the Resource interface, see the
> [cheatsheet]({{site.github.url}}/cheatsheet).

## 2 Attributes

A **Resource** is composed of **Attribute**s. Each Attribute has a
**name** (e.g. `first_name`) that corresponds to a JSON key, and a
**Type** (e.g. `string`) that corresponds to a JSON value.

To define an attribute:

{% highlight ruby %}
attribute :first_name, :string
{% endhighlight %}

#### 2.1 Limiting Behavior

Each attribute consists of four flags: `readable`, `writable`,
`sortable`, and `filterable`. Any of these flags can be turned off:

{% highlight ruby %}
attribute :name, :string, sortable: false
{% endhighlight %}

Or use `only/except` shorthand:

{% highlight ruby %}
attribute :name, :string, only: [:sortable]
attribute :name, :string, except: [:writable]
{% endhighlight %}

You might want to allow behavior only if a certain condition is met.
Pass a symbol to guard this behavior via corresponding method, only allowing the
behavior if the method returns `true`:

{% highlight ruby %}
attribute :name, :string, writable: :admin?

def admin?
  # ... logic ...
end
{% endhighlight %}

#### 2.2 Default Behavior

By default, attributes are enabled for all behavior. You may want to
disable certain behavior globally, for example a read-only API. Use
these properties to affect all subclasses:

{% highlight ruby %}
self.attributes_readable_by_default = false # default true
self.attributes_writable_by_default = false # default true
self.attributes_filterable_by_default = false # default true
self.attributes_sortable_by_default = false # default true
{% endhighlight %}

#### 2.3 Customizing Display

Pass a block to `attribute` to customize display:

{% highlight ruby %}
attribute :name, :string do
  @object.name.upcase
end
{% endhighlight %}

`@object` will be an instance of your model.

##### 2.3.1 Explicit Serializers

TODO

#### 2.4 Types

Each **Attribute** has a **Type**. Each **Type** defines behavior for

* Reading
* Writing
* Filtering

For each of these, we'll first attempt to *coerce* the given value to
the correct type. If that fails, we will raise an error.

The implementation for each of these actions lives in a [Dry Type](https://dry-rb.org/gems/dry-types). Take the `:integer_id` type: here we want to *render* a string, but *query* with an integer (this is the default for all Resource `id` attributes):

{% highlight ruby %}
Graphiti::Types[:integer_id]

# {
#   params: Dry::Types['coercible.integer'],
#   read: Dry::Types['coercible.string'],
#   write: Dry::Types['coercible.integer'],
#   ...
# }
{% endhighlight %}

You can edit these implementations as you wish. Let's make the `:string` type
render an integer:

{% highlight ruby %}
Graphiti::Types[:string][:read] = Dry::Types['coercible.integer']
{% endhighlight %}

The built-in Types are:

* `integer_id`
* `string`
* `integer`
* `big_decimal`
* `float`
* `date`
* `datetime`
* `boolean`
* `hash`
* `array`

All but the last 3 have Array doppelgängers: `array_of_integers`,
`array_of_dates`, etc.

##### 2.5 Custom Types

[Dry Types supports custom types](https://dry-rb.org/gems/dry-types/custom-types). Let's register a "capital letters" type:

{% highlight ruby %}
# Define the Type
definition = Dry::Types::Definition.new(String)
type = definition.constructor do |input|
  input.upcase
end

# Register it with Graphiti
Graphiti::Types[:caps_lock] = {
  params: type,
  read: type,
  write: type,
  kind: 'scalar',
  canonical_name: :caps_lock,
  description: 'All capital letters'
}

# Use in a Resource
attribute :name, :caps_lock
{% endhighlight %}

## 3 Querying

Resources must be able to dynamically compose a query that can be run
against an arbitrary backend (SQL, NoSQL, service calls, etc). They do
this through the concept of **scoping**.

The best way to understand scoping is to take a look at what happens "under the hood". Here's the simple Resource, where most of the logic is hiding in the Adapter:

{% highlight ruby %}
class PostResource < ApplicationResource
  attribute :title, :string
end
{% endhighlight %}

Now let's show the long-hand version. This is completely runnable code (we're just overriding the default behavior with an explicit version of the same):

{% highlight ruby %}
class PostResource < ApplicationResource
  filter :title do |scope, value|
    eq do |scope, value|
      scope.where(title: value)
    end
  end

  sort :title do |scope, dir|
    scope.order(title: dir)
  end

  paginate do |scope, current_page, per_page|
    scope.page(current_page).per(per_page)
  end

  def base_scope
    Post.all
  end

  def resolve(scope)
    scope.to_a
  end
end
{% endhighlight %}

Let's break this down the key elements:

{% highlight ruby %}
def base_scope
  Post.all
end
{% endhighlight %}

Graphiti builds queries just like ActiveRecord: start with a base scope (`Post.all`), and alter that scope based on the incoming request. `#base_scope` defines our starting point.

{% highlight ruby %}
filter :title do |scope, value|
  eq do |scope, value|
    scope.where(title: value)
  end
end
{% endhighlight %}

When the `title` query parameter is present, we alter the scope.

{% highlight ruby %}
def resolve(scope)
  scope.to_a
end
{% endhighlight %}

The `#resolve` method is in charge of actually executing the query
and returning model instances.

In other words, this code is roughly equivalent to:

{% highlight ruby %}
scope = Post.all # #base_scope
if value = params[:filter].try(:[], :title)
  scope = scope.where(title: value) # .filter
end
scope.to_a # #resolve
{% endhighlight %}

#### 3.1 Query Interface

Resources can query and persist data without an API request or
response. To query, pass a [JSONAPI-compliant](http://jsonapi.org) query hash:

{% highlight ruby %}
EmployeeResource.all({
  filter: { first_name: 'Jane' },
  sort: '-created_at',
  page: { size: 10, number: 2 }
})
{% endhighlight %}

The return value from `.all` is a **proxy** object, similar to
`ActiveRecord::Relation`:

{% highlight ruby %}
# ActiveRecord:
employees = Employee.all
employees.class # ActiveRecord::Relation
# No query fires until .map
employees.map(&:first_name) # => ["Jane", "Joe", ...]

# Graphiti Resource:
employees = EmployeeResource.all
employees.class # Graphiti::ResourceProxy
# No query fires until .map
employees.map(&:first_name) # => ["Jane", "Joe", ...]

# Access model instances directly
employees.data # => [#<Employee>, #<Employee>, ...]
{% endhighlight %}

This proxy object can render [JSONAPI](http://jsonapi.org), simple
JSON, or XML:

{% highlight ruby %}
employees = EmployeeResource.all
employees.to_jsonapi
employees.to_json
employees.to_xml
{% endhighlight %}

Use `.find` to find a single record by id, raising
`Graphiti::Errors::RecordNotFound` if no records are returned:

{% highlight ruby %}
employee = EmployeeResource.find(id: 123)
employee.data.first_name # => "Jane"
{% endhighlight %}

#### 3.2 Composing with Scopes



#### 3.3 `#base_scope`

Override the `#base_scope` method whenever you have logic that should
apply to *every* query. For example, if we only ever wanted to return
`active` Positions:

{% highlight ruby %}
def base_scope
  Position.where(active: true)
end
{% endhighlight %}

This can be overridden by passing a second argument to `Resource.all`:

{% highlight ruby %}
class InactivePostsController < PostsController
  def index
    posts = PostResource.all(params, Post.where(active: false))
    respond_with(posts)
  end
end
{% endhighlight %}

#### 3.4 Sort

Use the `sort` DSL to customize sorting behavior.

{% highlight ruby %}
sort :name, :string do |scope, direction|
  scope.order(first_name: direction, last_name: direction)
end
{% endhighlight %}

If you've already defined a corresponding attribute, you'll be
overriding that default behavior (and there is no need to pass a type as
the second argument):

{% highlight ruby %}
attribute :name, :string

sort :name do |scope, direction|
  # ... code ...
end
{% endhighlight %}

> Note: `sort` defines a sort-only attribute. If you want other
> behavior, like filtering, it's best to define the attribute first.

##### 3.4.1 Sort Options

Pass `:only` if you support just a single direction:

{% highlight ruby %}
sort :name, only: [:desc]
{% endhighlight %}

#### 3.5 Filter

Use the `filter` DSL to customize each *operator*:

{% highlight ruby %}
filter :name, :string do
  eq do |scope, value|
    scope.where(first_name: value)
  end

  # prefix do ... end
  # suffix do ... end
  # etc
end
{% endhighlight %}

> Note that Graphiti expects filters to support multiple values by
> default, so `value` will be an array. Pass `single: true` if you do
> not support multiple values.

> To pass multiple values in a query string, comma-delimit:
> `/employees?filter[name]=Jane,John`

If you've already defined a corresponding attribute, you'll be
overriding that default behavior (and there is no need to pass a type as
the second argument):

{% highlight ruby %}
attribute :name, :string

filter :name do
  eq do |scope, value|
    # ... code ...
  end
end
{% endhighlight %}

You can define custom operators on-the-fly:

{% highlight ruby %}
filter :name do
  fuzzy_match do |scope, value|
    # ... code ...
  end
end
{% endhighlight %}

Will now support `filter[name][fuzzy_match]=foo`

> Note: `filter` defines a filter-only attribute. If you want other
> behavior, like sorting, it's best to define the attribute first.

##### 3.5.1 Filter Options

Pass `:only` or `:except` to limit possible operators:

{% highlight ruby %}
filter :name, :string, only: [:eq, :suffix]
{% endhighlight %}

Pass `:allow` or `:reject` to only allow filtering on certain values, or
reject bad values:

{% highlight ruby %}
filter :size, :string, allow: ['Big', 'Medium', 'Small']

filter :size, :string, reject: ['X-Large']
{% endhighlight %}

By default, all filters accept multiple values, causing the yielded
`value` to always be an array. Pass `single: true` to only allow a
single value:

{% highlight ruby %}
# Default behavior
filter :name, :string do
  eq do |scope, value|
    value # => ["Jane"]
  end
end

# With single: true
filter :name, :string, single: true do
  eq do |scope, value|
    value # => "Jane"
  end
end
{% endhighlight %}

Filters can be required:

{% highlight ruby %}
# Via attribute
attribute :customer_id, :integer, filterable: :required

# Via filter
filter :customer_id, :string, required: true
{% endhighlight %}

Filters can also depend on other filters, requiring all criteria to be
present:

{% highlight ruby %}
# We query customers by id AND type, not one or the other
filter :customer_id, :integer, dependent: [:customer_type]
filter :customer_type, :string, dependent: [:customer_id]
{% endhighlight %}

##### 3.5.2 Boolean Filter

It doesn't make sense for a filter with type `boolean` to accept
multiple values. These filters will be `single: true` by default.

##### 3.5.3 Hash Filter

Filters with type `hash` will automatically parse JSON when passed in a
URL query string:

{% highlight ruby %}
# GET /employees?filter[metadata]={ "foo": 100 }

filter :metadata, :hash do
  eq do |scope, value|
    value # => [{ "foo" => 100 }]
  end
end
{% endhighlight %}

##### 3.5.4 Escaping Values

By default, Graphiti parses a comma-delimited string as an array. There
are times you may not want this - for instance a "keyword search" field
that could contain a comma.

Wrap values in {% raw %}`{{curlies}}`{% endraw %} to avoid parsing:

{% highlight ruby %}
{% raw %}
# GET /employees?filter[keywords]={{some,value}}

filter :keywords, :string do
  eq do |scope, value|
    value # => "some,value"
  end
end
{% endraw %}
{% endhighlight %}

You can also define arrays explicitly instead of delimiting on comma:

{% highlight ruby %}
# GET /employees?filter[keywords]=[some,value]

filter :keywords, :string do
  eq do |scope, value|
    value # => ["some", "value"]
  end
end
{% endhighlight %}

#### 3.6 Statistics

Statistics are useful and common. Consider a datagrid listing posts - we might want a "Total Posts" count displayed above the grid without firing an additional request. Notably, that statistic **should** take into account filtering, but **should not** take into account pagination.

All resources have a total count statistic by default:

{% highlight ruby %}
PostResource.all({
  stats: { total: 'count' }
})
{% endhighlight %}

`/posts?stats[total]=count`

Would cause the `meta` section of the response to be:

{% highlight ruby %}
{
  meta: {
    stats: {
      total: {
        count: 100
      }
    }
  }
}
{% endhighlight %}

Allow a given statistic to be requested using `.stat`:

{% highlight ruby %}
stat total: [:count]
stat rating: [:average]
stat likes: [:sum]
stat score: [:maximum]
stat score: [:maximum]

# e.g.
# {
#   meta: {
#     stats: {
#       rating: {
#         average: 74
#       }
#     }
#   }
# }
{% endhighlight %}

You can also define custom statistics:

{% highlight ruby %}
stat rating: [:average] do
  standard_deviation do |scope, attr|
    # your standard deviation code here
  end
end
{% endhighlight %}

#### 3.7 `#resolve`

After we build up a query, we pass it to `#resolve`. Resolve **must** do
two things:

* Execute the query
* Return an array of `Model` instances

Override `#resolve` if you need more than the default behavior:

{% highlight ruby %}
def resolve(scope)
  Rails.logger.info "begin resolving scope..."
  result = super
  Rails.logger.info "resolved!"
  result
end
{% endhighlight %}

## 4 Configuration

Here's a Resource with explicit defaults:

{% highlight ruby %}
class PostResource < ApplicationResource
  self.model = Post
  self.type = 'posts'

  # Only used if you care about Links
  primary_endpoint '/posts', [:index, :show, :create, :update, :destroy]

  # default nil
  self.default_sort = [{ title: :asc }]

  # default 20
  self.default_page_size = 10
end
{% endhighlight %}

Typically you'd inherit from `ApplicationResource`. Here are some common higher-level customization options that will affect subclasses:

{% highlight ruby %}
class ApplicationResource < Graphiti::Resource
  # Must be set when no corresponding model/query
  self.abstract_class = true

  # Subclasses can override if needed
  self.adapter = Graphiti::Adapters::ActiveRecord::Base

  # Default attribute flags:
  # attribute :title, :string,
  #   readable: default,
  #   writable: default,
  #   sortable: default,
  #   filterable: default
  self.attributes_readable_by_default = true
  self.attributes_writable_by_default = true
  self.attributes_sortable_by_default = true
  self.attributes_filterable_by_default = true

  # Used for link generation
  self.base_url = Rails.application.routes.default_url_options[:host]
  # Used for link generation
  # Suggest referencing this config/routes.rb:
  # scope path: ApplicationResource.endpoint_namespace do
  #   resources :posts
  # end
  self.endpoint_namespace = '/api/v1'

  # Will raise an error if a resource is being accessed from a URL it is not allowlisted for
  # Helpful for link validation
  self.validate_endpoints = false

  # Automatically generate JSONAPI links?
  self.autolink = true
end
{% endhighlight %}

### 4.1 Polymorphic Resources

Polymorphic Resources are similar to [ActiveRecord STI](https://api.rubyonrails.org/classes/ActiveRecord/Inheritance.html): when a single query can return multiple Resource instances. We may query `/tasks`, but return `bugs`, `features`, `epics`, etc.

For example, given the `ActiveRecord` models:

{% highlight ruby %}
class Employee < ApplicationRecord
  has_many :tasks
end

# tasks table has a 'type' column
class Task < ApplicationRecord
  belongs_to :employee
end

class Bug < Task
end

# ONLY Feature has #points
class Feature < Task
  def points
    5
  end
end

# ONLY Epic has the milestones relationship
class Epic < Task
  has_many :milestones
end

class Milestone < ApplicationRecord
  belongs_to :epic
end
{% endhighlight %}

We could define the following Polymorphic Resources:

{% highlight ruby %}
class TaskResource < ApplicationResource
  # Reference child classes
  self.polymorphic = [
    'BugResource',
    'FeatureResource',
    'EpicResource'
  ]

  attribute :title, :string
end

class BugResource < TaskResource
end

class FeatureResource < TaskResource
  attribute :points, :integer
end

class EpicResource < TaskResource
  has_many :milestones
end

class MilestoneResource < TaskResource
  belongs_to :epic
end
{% endhighlight %}

If we hit a `/tasks` endpoint, we'd get back [JSONAPI types](http://jsonapi.org/format/#document-resource-identifier-objects) of `bugs`, `features` and `epics`. Only `features` would render the `points` attribute, and only `epics` would render the `milestones relationship`.

A query to `/tasks?include=milestones` would correctly only query
and render Milestones for Epics.

## 5 Relationships

Resources can connect to other Resources via **relationships**.
Each relationship determines behavior for:

* Sideloading (load both Resources in a single request)
* Links (URL to lazy-load in separate request)
* Sideposting (save both in single request)

When connecting resources, you can imagine the logic similar to
`ActiveRecord`'s `.includes`:

{% highlight ruby %}
class PostResource < ApplicationResource
  has_many :comments
end

class CommentResource < ApplicationResource
  attribute :post_id, :integer, only: [:filterable]
  belongs_to :post
end

PostResource.all(includes: 'comments')
# Under the hood:
# CommentResource.all(filter: { post_id: array_of_post_ids })

CommentResource.all(includes: 'post')
# Under the hood:
# PostResource.all(filter: { id: array_of_comment_ids })
{% endhighlight %}

> Note the explicit `post_id` filter on `CommentResource`

### 5.1 Deep Queries

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

#### 5.2 Customizing Relationships

The default options you can override are:

{% highlight ruby %}
has_many :positions,
  foreign_key: :employee_id,
  primary_key: :id,
  resource: EmployeeResource,
  readable: true,
  writable: true,
  link: self.autolink # default true
  single: false # only allow this sideload when one employee
{% endhighlight %}

Use `params` to change the query parameters that will be passed to the
associated Resource:

{% highlight ruby %}
has_many :active_positions do
  params do |hash|
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
{% endhighlight %}

Once we've fetched primary data and its relationship (e.g. we have an
`employees` array and `positions` array), we need to associate these
objects:

{% highlight ruby %}
employees.each do |e|
  e.positions = positions.select { |p| p.employee_id == e.id }
end
{% endhighlight %}

Occasionally this logic will be non-standard or more complex. Use
`assign_each` to customize:

{% highlight ruby %}
has_many :positions do
  assign_each do |employee, positions|
    positions.select { |p| p.belongs_to?(employee) }
  end
end
{% endhighlight %}

#### 5.3 has_many

{% highlight ruby %}
has_many :positions
{% endhighlight %}

Defaults to these common options:

{% highlight ruby %}
has_many :positions,
  foreign_key: :employee_id,
  primary_key: :id,
  resource: PositionResource
{% endhighlight %}

Which would cause the following query when sideloading:

{% highlight ruby %}
PositionResource.all({ filter: { employee_id => employee_ids } })
{% endhighlight ruby %}

This means **we need to make sure that filter is supported**:

{% highlight ruby %}
class PositionResource < ApplicationResource
  attribute :employee_id, :integer, only: [:filterable]
  # ... code ...
end
{% endhighlight ruby %}

Once we've resolved `employees` and `positions` the resulting objects
would be associated with logic similar to:

{% highlight ruby %}
employees.each do |e|
  e.positions = positions.select { |p| p.employee_id == e.id }
end
{% endhighlight %}

And generate a Link:

`/positions?filter[employee_id]=1,2,3`

#### 5.4 belongs_to

{% highlight ruby %}
belongs_to :employee
{% endhighlight %}

Defaults to these common options:

{% highlight ruby %}
belongs_to :employee,
  foreign_key: :employee_id,
  primary_key: :id,
  resource: EmployeeResource
{% endhighlight %}

Which would cause the following query when sideloading:

{% highlight ruby %}
EmployeeResource.all({ filter: { id => position_ids } })
{% endhighlight ruby %}

And assign the resulting objects with logic similar to:

{% highlight ruby %}
positions.each do |p|
  p.employee = employees.find { |e| p.employee_id == e.id }
end
{% endhighlight %}

And generate a Link:

`/employees?filter[id]=1,2,3`

#### 5.4 has_one

`has_one` works exactly like `has_many`, but only one record will be
returned. When sideloading this will be a single element, much like
`belongs_to`.

There is one small caveat: Links always point to an `index` action, so
we can apply filters. That means following *`has_one` Link will lead to
an array*, and you should select the first record.

##### 5.4.1 Faux has_one

A "Faux Has One" occurrs when there is more than one record of
associated data, but we only want to return the *first* record in that
array. Consider this `ActiveRecord` relationship:

{% highlight ruby %}
# app/models/employee.rb
has_many :positions
has_one :current_position, -> { where(created_at: :desc) }

Employee.includes('current_position').to_a

# SELECT * FROM employees
# SELECT * FROM positions WHERE employee_id IN (?) ORDER BY created_at DESC
{% endhighlight %}

When we eager load, *more than one Position is returned from the
database query*. Assigning only the first record and dropping the rest
occurs in ruby, not the database query.

The same thing happens in Graphiti:

{% highlight ruby %}
# app/resources/employee_resource.rb
has_many :positions
has_one :current_position do
  params do |hash|
    hash[:sort] = '-created_at'
  end
end

EmployeeResource.all(include: 'current_position')
# PositionResource.all({
#   filter: { employee_id: employee_ids },
#   sort: '-created_at'
# })
{% endhighlight %}

Though everything works as expected, a large number of Position records
can incur a performance penalty (as we'd be instantiating a large number
of ActiveRecord objects).

For this reason, you are encouraged to model Faux Has One's in such a
way that the underlying database query only returns the relevant single
record. Imagine if we had a `historical_index` column on `positions`,
where a value of `1` meant "most recent":

{% highlight ruby %}
# app/models/employee.rb
has_many :positions
has_one :current_position, -> { where(historical_index: 1) }

Employee.includes('current_position').to_a

# SELECT * FROM employees
# SELECT * FROM positions WHERE employee_id IN (?) AND historical_index = 1
{% endhighlight %}

We've ensured the *query itself* only returns a single record.
Optimizing a Graphiti API is the same as optimizing queries.

##### 5.5 many_to_many

> This relationship is specific to relational databases that use a "join
> table" between two tables.

Though you can make this work for other ORMs/clients, it's easiest to
explain by focusing on `ActiveRecord`.

First, **you must use [has_many :through](https://guides.rubyonrails.org/association_basics.html#the-has-many-through-association) and not has_and_belongs_to_many**:

{% highlight ruby %}
class Employee < ApplicationRecord
  has_many :team_memberships
  has_many :teams, through :team_memberships
end

class TeamMembership < ApplicationRecord
  belongs_to :employee
  belongs_to :team
end

class Team < ApplicationRecord
  has_many :team_memberships
  has_many :employees, through: :team_memberships
end
{% endhighlight %}

You can always expose `team_memberships` to your API - particularly
useful if that table holds metadata about the relationship.

Other times, however, clients of the API should not have knowledge of
this implementation detail. In these cases, use `many_to_many`:

{% highlight ruby %}
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
{% endhighlight %}

The `many_to_many` call will automatically add a Filter to the
associated resource. The logic for that filter, in the case of `ActiveRecord`:

{% highlight ruby %}
# app/resources/employee_resource.rb

filter :team_id, :integer do
  eq do |scope, value|
    scope
      .includes(:team_memberships)
      .where(team_memberships: { team_id: value }
  end
end
{% endhighlight %}

To customize the foreign key, you will need to specify a hash rather
than a symbol. The hash key is the relationship name, so the above is
equivalent to

{% highlight ruby %}
# app/resources/employee_resource.rb

many_to_many :teams, foreign_key: { team_memberships: :team_id }
{% endhighlight %}

If using ActiveRecord, and the API relationship name does not match your
Model relationship name, use `:as` to specify the model relationship
that should be used to derive the query:

{% highlight ruby %}
# The API relationship is "teams", ActiveRecord has "groups"
many_to_many :teams, as: :groups
{% endhighlight %}

##### 5.5 polymorphic_belongs_to

With polymorphic associations, a Resource can belong to more than one other Resource, on a single association. Though these relationships are not specific to `ActiveRecord`, we'll use `ActiveRecord` conventions to describe the use case.

Given the following [polymorphic ActiveRecords](https://guides.rubyonrails.org/association_basics.html#polymorphic-associations):

{% highlight ruby %}
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
{% endhighlight %}

By `ActiveRecord` convention, the `notes` table would have columns
`notable_id` and `notable_type`.

Graphiti has the same concept. In this case we would group all the notes
by a given `notable_type`, and follow a different `belongs_to`
association for each group:

{% highlight ruby %}
# app/resources/note_resource.rb
polymorphic_belongs_to :notable do
  group_by(:notable_type) do
    on(:Employee)
    on(:Department)
    on(:Team)
  end
end
{% endhighlight %}

The `on` DSL is shorthand for a `belongs_to` relationship that accepts
all the usual options and customizations:

{% highlight ruby %}
on(:Employee).belongs_to :employee,
  resource: EmployeeResource
  # ... etc ...
{% endhighlight %}

In other words: group all Notes by `notable_type`, and for all that have
the value of `"Employee"` use the `belongs_to :employee` relationship
for further querying.

##### 5.6 polymorphic_has_many

Continuing from the prior section, the corresponding association of a
`polymorphic_belongs_to` is a `polymorphic_has_many`:

{% highlight ruby %}
class EmployeeResource < ApplicationResource
  polymorphic_has_many :notes, as: :notable
end
{% endhighlight %}

Predictably, this causes the query:

{% highlight ruby %}
NoteResource.all({
  filter: {
    notable_type: 'Employee',
    notable_id: employee_ids
  }
})
{% endhighlight %}

And the Link

`/notes?filter[notable_id]=1,2,3&filter[notable_type]=Employee`

Which means the following filters are required:

{% highlight ruby %}
class NoteResource < ApplicationResource
  attribute :notable_id, :integer, only: [:filterable]
  attribute :notable_type, :string, only: [:filterable]
  # ... code ...
end
{% endhighlight %}

## 6 Generators

To generate a Resource:

{% highlight bash %}
$ rails generate graphiti:resource NAME [attribute:type] [options]
{% endhighlight %}

For example:

{% highlight bash %}
$ rails generate graphiti:resource Employee first_name:string age:integer
{% endhighlight %}

Will add a route, controller, resource, and tests.

Limit the actions this resource supports with `-a`:

{% highlight bash %}
$ rails generate graphiti:resource Employee -a index show
{% endhighlight %}

## 7 Persisting

Graphiti allows writing a graph of data in a single request. We'll do
the work of parsing the graph and ordering operations, so you can focus
on the part you care about: the logic for actually persisting an object.

By default, persistence operations are handled by your adapter. The
"expanded" view of the ActiveRecord implementation is below:

{% highlight ruby %}
# app/resources/employee_resource.rb

def create(attributes)
  employee = Employee.new
  attributes.each_pair do |key, value|
    employee.send(:"#{key}=", value)
  end
  employee.save
  employee
end

def update(attributes)
  employee = EmployeeResource.find(attributes.delete(:id)).data
  attributes.each_pair do |key, value|
    employee.send(:"#{key}=", value)
  end
  employee.save
  employee
end

def destroy(attributes)
  employee = EmployeeResource.find(attributes.delete(:id)).data
  employee.destroy
  employee
end
{% endhighlight %}

* You are encouraged **not** to override these directly. Instead, use
hooks (see next section).
* We'll process any `writable: false` or guarded attributes prior to
these methods.
* After these methods, we'll check the Model instance for validation
errors, rolling back the transaction if any Model in the graph is
invalid.
* These methods **must return the Model instance**.

### 7.1 Persistence Lifecycle Hooks

Let's dive into a persistence request. If you look at the code snippets in
the prior section, the flow breaks down into 3 steps:

* Build or find the model
* Assign attributes to the model
* Save

You can hook into each step:

{% highlight ruby %}
class PostResource < ApplicationResource
  before_attributes do |attributes|
    # Before attributes have been assigned to the model
  end

  after_attributes do |model|
    # After attributes have been assigned to the model
  end

  around_attributes :do_around_attributes

  def do_around_attributes(attributes)
    # before
    model_instance = yield attributes
    # after
  end

  before_save do |model|
    # After attributes assigned, but before persisting
  end

  after_save do |model|
    # After model has been saved
  end

  around_save :do_around_save

  def do_around_save(model)
    # before
    yield model
    # after
  end

  # This is an *override*
  # During #create, build a blank model instance
  # By default, we'd call adapter.build(model_class)
  def build(model_class)
    model_class.new
  end

  # This is an *override*
  # During #create/#update, assign new attributes to the model instance
  # By default, we'd call adapter.assign_attributes(model_instance, attributes)
  def assign_attributes(model_instance, attributes)
    attributes.each_pair do |key, value|
      model_instance.send(:"#{key}=", value)
    end
  end

  # This is an *override*
  # During #create/#update, actually save the model instance
  # By default, we'd call adapter.save(model_instance)
  def save(model_instance)
    model_instance.save
  end

  # This is an *override*
  # During #destroy, actually save the model instance
  # By default, we'd call adapter.destroy(model_instance)
  def delete(model_instance)
    model.destroy
  end

  # Finally, you may want to hook around *all* the above steps:
  # Only applies to #create/#update
  around_persistence :do_around_persistence

  def do_around_persistence(attributes)
    attributes[:foo] = 'bar'
    model = yield # build/find, assign attrs, save
    model.update_counter_cache
  end
end
{% endhighlight %}

* All hooks have `only/except` options, e.g. `before_attributes only:
[:update]`
* Most hooks can be called with an in-line block, or by passing a method
name (e.g. `before_attriubtes :do_something`). The exception is
`around_*` hooks, which *must* be called with a method name.

When persisting multiple objects at once, we'll open a database
transaction, process each model individually, ensure all models pass
validation, then close the transaction. This means that if you raise an
error at any point, or any model does not pass validations, the
transaction will be rolled back.

You may want to perform an operation after all models have been
processed and validated, but before the transaction is closed. One
example is sending an email - you don't want to send if the models were
invalid, so `after_save` wouldn't work. And you still want to do it
*within* the transaction, so if your email server is down and an error
is raised the transaction gets rolled back.

For this scenario, use `before_commit`:

{% highlight ruby %}
before_commit do |model|
  PostMailer.with(post: model).some_email.deliver
end
{% endhighlight %}

### 7.2 Sideposting

The act of persisting multiple Resources in a single request is called
**Sideposting**. The payload mirrors the **sideloading** payload for
read operations, with minor additions.

Let's create a Post and associate it to an existing Blog in a single
request:

{% highlight ruby %}
# POST /api/v1/posts
{
  type: 'posts',
  attributes: { title: 'My post' },
  relationships: {
    blog: {
      data: {
        id: '1',
        type: 'blogs',
        method: 'update'
      }
    }
  }
}
{% endhighlight %}

The critical addition here is the `method` key. When we persist RESTful
Resources, we send a corresponding HTTP verb. This follows the same
pattern, adding a verb for each Resource in the graph. `method` can be
one of:

  * `create`
  * `update`
  * `destroy`
  * `disassociate` (e.g. `null` foreign key)

When we sidepost, all objects will be persisted within the same database
transaction, which rolls back if an error is raised or any objects are invalid.

#### 7.2.1 Create

Let's say we want to create a Post and its Blog in a single request.
You'll note that we don't have the `id` key to generate a [Resource
Identifier](http://jsonapi.org/format/#document-resource-identifier-objects) (combination of `id` and `type`
that uniquely identifies a Resource).

To accomodate this, send an ephemeral `temp-id` (any UUID):

{% highlight ruby %}
{
  # POST /api/v1/posts
  {
    type: 'posts',
    attributes: { title: 'My post' },
    relationships: {
      blog: {
        data: {
          :'temp-id' => 'abc123',
          type: 'blogs',
          method: 'create'
        }
      }
    },
    included: [
      {
        :'temp-id' => 'abc123'
        type: 'blogs',
        attributes: { name: 'New Blog' }
      }
    ]
  }
}
{% endhighlight %}

This random UUID:

* Connects relevant sections of the payload.
* Tells clients how to associate their in-memory objects with the ids returned from the server.

#### 7.2.2 Expanded Example

Here we're updating a Post, changing the name of its associated Blog, creating a Tag, deleting one Comment, and disassociating (`null` foreign key) a different Comment, all in a single request:

{% highlight ruby %}
{
  data: {
    type: 'posts',
    id: 123,
    attributes: { title: 'Updated!' },
    relationships: {
      blog: {
        data: {
          type: 'blogs',
          id: 123,
          method: 'update'
        }
      },
      tags: {
        data: [{
          type: 'tags',
          temp-id: 's0m3uu1d',
          method: 'create'
        }]
      },
      comments: {
        data: [
          {
            type: 'comments',
            id: '123',
            method: 'destroy'
          },
          {
            type: 'comments',
            id: '456',
            method: 'disassociate'
          }
        ]
      }
    }
  },
  included: [
    {
      type: 'tags',
      :'temp-id' => 's0m3uu1d',
      attributes: { name: 'Important' }
    },
    {
      type: 'blogs',
      id: => '123',
      attributes: { name: 'Updated!' }
    }
  ]
}
{% endhighlight %}

### 7.3 Validation Errors

When a persistence operation is attempted but the corresponding Resource
is invalid, the transaction will be rolled back and an [errors payload](http://jsonapi.org/format/#errors) will be returned
with a `422` response code:

{% highlight ruby %}
{
  errors: [{
    code:  'unprocessable_entity',
    status: '422',
    title: "Validation Error",
    detail: "Title can't be blank",
    source: { pointer: '/data/attributes/title' },
    meta: {
      attribute: :title,
      message: "can't be blank",
      code: :blank
    }
  }]
}
{% endhighlight %}

To get this functionality, your Model must adhere to the
[ActiveModel::Validations API](https://api.rubyonrails.org/classes/ActiveModel/Validations.html).

You get this for free with ActiveRecord, or it can be mixed in to any
PORO:

{% highlight ruby %}
class Post
  include ActiveModel::Validations
  validates :title, presence: true
end
{% endhighlight %}

Errors on associations will have a slightly expanded payload:

{% highlight ruby %}
{
  errors: [{
    code: 'unprocessable_entity',
    status: '422',
    title: 'Validation Error',
    detail: "Name can't be blank",
    source: { pointer: '/data/attributes/name' },
    meta: {
      relationship: {
        attribute: :name,
        message: "can't be blank",
        code: :blank,
        name: :pets,
        id: '444',
        type: 'pets'
      }
    }
  }]
}
{% endhighlight %}

When [Sideposting](#sideposting), the errors payload will contain all
invalid Resources in the graph.

## 7.4 Read on Write

By default, the response of a persistence operation will mirror your
request. But sometimes you need control over the response. The most
common scenario is sideloading an additional entity - imagine creating
an order, and wanting the order's shipping information to come back in
the response.

You can do this by POSTing the payload as normal, but adding query
parameters to the URL:

```
POST /api/v1/orders?include=shipping_information

{
  type: 'orders',
  attributes: { ... }
}
```

This will sideload the shipping information in the response. When using
[Spraypaint]({{site.github.url}}/js/home), do this with:

{% highlight js %}
order.save({ returnScope: Order.includes('shipping_information') })
{% endhighlight %}

## 8 Context

All resources have access to `#context`. If you're using Rails,
`context` is the controller instance processing the request.

{% highlight ruby %}
# app/resources/post_resource.rb
attribute :active, :boolean, writable: :admin?

def admin?
  context.current_user.admin?
end
{% endhighlight %}

Because `current_user` is so common, we recommend putting this in
`ApplicationResource`:

{% highlight ruby %}
# app/resources/application_resource.rb
class ApplicationResource < Graphiti::Resource
  # ... code ...
  def current_user
    context.current_user
  end
end

# app/resources/post_resource.rb
class PostResource < ApplicationResource
  # ... code ...
  def admin?
    current_user.admin?
  end
end
{% endhighlight %}

You can manually set context with `with_context`:

{% highlight ruby %}
ctx = OpenStruct.new(current_user: User.first)
Graphiti.with_context(ctx) do
  # current_user == ctx.current_user
  PostResource.all
end
{% endhighlight %}

<br />
<br />

</div>
