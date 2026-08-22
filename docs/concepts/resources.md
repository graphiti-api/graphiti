---
title: 'Resources'
---

# Resources

A Resource is an abstraction around an API endpoint, the way a Model is an abstraction around a database table. It holds the logic for **querying**, **persisting**, and **serializing** one kind of thing.

```ruby
class EmployeeResource < ApplicationResource
  attribute :first_name, :string
  attribute :age, :integer

  has_many :positions
end
```

This page is the full reference. For the whole API on one screen, see the [cheatsheet on the home page](/). For how a request flows through a Resource, see [Lifecycle of a Request](/concepts/overview).

Resources connect to each other. That's covered separately in [Relationships](/concepts/relationships), and writes in [Persisting](/concepts/persisting).

## Attributes {#attributes}

```ruby
attribute :first_name, :string
```

A **name** (`first_name`) maps to a JSON key. A **Type** (`string`) maps to a JSON value and its coercion rules.

### Limiting Behavior {#limiting-behavior}

```ruby
attribute :name, :string,
  readable: true,   # renders in responses
  writable: true,   # accepted on create/update
  sortable: true,   # ?sort=name works
  filterable: true, # ?filter[name]=... works
  schema: true       # exported to schema.json, not affected by only/except
```

Turn any flag off directly, or with `only`/`except` shorthand:

```ruby
attribute :name, :string, sortable: false
attribute :name, :string, only: [:sortable]
attribute :name, :string, except: [:writable]
```

**Guards.** `readable` and `writable` also accept a symbol, string, or proc. The behavior applies only when the guard returns `true`, and the guard's arity decides what it receives:

```ruby
attribute :name,   :string,  writable: :admin?
attribute :salary, :integer, readable: :visible?, writable: :salary_writable?

def admin?                                  # no arguments
  context.current_user.admin?
end

def visible?(model)                         # the model
  model.internal == false
end

def salary_writable?(model, attribute_name) # the model and the attribute name
  PolicyChecker.new(model).attribute_writable?(attribute_name)
end
```

The model is only looked up when a guard declares a parameter for it, so zero-argument guards cost nothing. On an update it's the persisted record. On a create, it's a new unsaved instance.

| Guard returns `false` on | Result |
| --- | --- |
| `readable` | The attribute is omitted from the response. |
| `writable` | The request is rejected with an `unwritable_attribute` validation error, before anything is persisted. |

### Default Behavior {#default-behavior}

```ruby
# On ApplicationResource, affects every subclass
self.attributes_readable_by_default = false   # default true
self.attributes_writable_by_default = false   # default true
self.attributes_filterable_by_default = false # default true
self.attributes_sortable_by_default = false   # default true
self.attributes_schema_by_default = false     # default true
```

Each `*_by_default` setting can also be a guard symbol, delegating the check to a method. Useful for wiring every attribute through one authorization system:

```ruby
self.attributes_readable_by_default = :attribute_readable?

def attribute_readable?(model_instance, attribute_name)
  PolicyChecker.new(model_instance).attribute_readable?(attribute_name)
end
```

### Customizing Display {#customizing-display}

```ruby
attribute :name, :string do
  @object.name.upcase # @object is the model instance
end
```

### Types {#types}

| Type | Notes |
| --- | --- |
| `string` | |
| `integer` | |
| `integer_id` | Renders as a string, queries/persists as an integer. Default type for `id`. |
| `uuid` | Like `string`, but only `eq`/`not_eq`, case-sensitive by default. |
| `string_enum` | Like `string`, but only `eq`/`not_eq`/`eql`/`not_eql`, and requires `allow:`. |
| `integer_enum` | Like `integer`, but only `eq`/`not_eq`, and requires `allow:`. |
| `big_decimal` | |
| `float` | |
| `boolean` | |
| `date` | |
| `datetime` | |
| `hash` | |
| `array` | |

Every type except `boolean`, `hash`, and `array` also has an `array_of_*` variant: `array_of_integers`, `array_of_dates`, `array_of_uuids`, and so on.

Each Type governs reading, writing, and filtering by wrapping a [Dry Type](https://dry-rb.org/gems/dry-types). Inspect one to see its parts:

```ruby
Graphiti::Types[:integer_id]

# {
#   params: Dry::Types['coercible.integer'],
#   read: Dry::Types['coercible.string'],
#   write: Dry::Types['coercible.integer'],
#   ...
# }
```

Edit an implementation in place. Here, `:string` is made to render as an integer:

```ruby
Graphiti::Types[:string][:read] = Dry::Types['coercible.integer']
```

#### Disabling Read Typecasting {#typecast-reads}

To serialize values exactly as the model returns them, skipping the type's `read` coercion:

```ruby
class ApplicationResource < Graphiti::Resource
  self.typecast_reads = false
end
```

Defaults to `true`. Like the other class attributes it inherits, so it can be turned off app-wide or per resource. Writes and filters still coerce.

#### Enum Types {#enum-types}

`string_enum` and `integer_enum` behave like `string` and `integer`, except declaring one (as an attribute or a filter) requires the `allow:` option, the list of acceptable values:

```ruby
attribute :status, :string_enum, allow: ['draft', 'published']
```

If your attribute is backed by an ActiveRecord enum, reference the values directly:

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  enum status: {
    draft: 0,
    published: 1
  }
end

# app/resources/post_resource.rb
class PostResource < ApplicationResource
  attribute :status, :string_enum, allow: Post.statuses.keys
end
```

See [Filter Options](#filter-options) for more on `allow`.

Graphiti does not validate enum values on write. Your model layer is still expected to validate incoming data.

#### Custom Types {#custom-types}

[Dry Types supports custom types](https://dry-rb.org/gems/dry-types/main/custom-types/):

```ruby
# Define the Type
definition = Dry::Types::Nominal.new(String)
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
```

## Querying {#querying}

```ruby
class PostResource < ApplicationResource
  # Applies to every query: start with a base scope, alter it based on
  # the incoming request. Called just like ActiveRecord's Post.all.
  def base_scope
    Post.all
  end

  # Must execute the query and return an array of Model instances.
  def resolve(scope)
    scope.to_a
  end
end
```

### Query Interface {#query-interface}

Resources can query and persist without an API request or response. Pass a [JSONAPI-compliant](http://jsonapi.org) query hash directly:

```ruby
EmployeeResource.all({
  filter: { first_name: 'Jane' },
  sort: '-created_at',
  page: { size: 10, number: 2 }
})
```

The return value from `.all` is a **proxy** object, similar to `ActiveRecord::Relation`. No query fires until you call `.map`, `.data`, or a render method:

```ruby
employees = EmployeeResource.all
employees.class     # Graphiti::ResourceProxy
employees.map(&:first_name) # => ["Jane", "Joe", ...]
employees.data       # => [#<Employee>, #<Employee>, ...]

employees.to_jsonapi
employees.to_json
employees.to_xml
```

`.find` returns a single record's proxy by id, raising `Graphiti::Errors::RecordNotFound` if none are returned:

```ruby
employee = EmployeeResource.find(id: 123)
employee.data.first_name # => "Jane"
```

### Composing with Scopes {#composing-with-scopes}

#### #base_scope {#base-scope}

```ruby
def base_scope
  Position.where(active: true)
end
```

Override `#base_scope` for logic that should apply to every query. Here, it only ever returns active Positions.

Pass a second argument to `.all` to override the base scope for a single call:

```ruby
class InactivePostsController < PostsController
  def index
    posts = PostResource.all(params, Post.where(active: false))
    render jsonapi: posts
  end
end
```

### Sort {#sort}

```ruby
sort :name, :string do |scope, direction|
  scope.order(first_name: direction, last_name: direction)
end
```

Omit the type if a matching `attribute` is already defined. This overrides its default sort behavior:

```ruby
attribute :name, :string

sort :name do |scope, direction|
  # ... code ...
end
```

`sort` on its own defines a sort-only attribute. Define the `attribute` first if you also need filtering or other behavior.

#### Sort Options {#sort-options}

| Option | Description |
| --- | --- |
| `only` | Restrict to a single direction, e.g. `sort :name, only: [:desc]` |

### Filter {#filter}

```ruby
filter :name, :string do
  eq do |scope, value|
    scope.where(first_name: value)
  end

  # prefix do ... end
  # suffix do ... end
  # etc
end
```

Omit the type if a matching `attribute` is already defined. This overrides its default filter behavior. `filter` on its own defines a filter-only attribute. Define the `attribute` first if you also need sorting or other behavior.

Every operator below also has a `not_` counterpart (`not_eq`, `not_prefix`, ...). Values arrive as an array unless the filter is `single: true`. Comma-delimit multiple values in a query string (`/employees?filter[name]=Jane,John`).

| Type | Default operators |
| --- | --- |
| `string` | `eq`, `eql`, `prefix`, `suffix`, `match` |
| `uuid` | `eq` |
| `string_enum`, `integer_enum` | `eq`, `eql` |
| `integer_id`, `integer`, `big_decimal`, `float`, `date`, `datetime` | `eq`, `gt`, `gte`, `lt`, `lte` |
| `boolean` | `eq` (always `single: true`) |
| `hash` | `eq` |
| `array` | `eq` |

Define custom operators on the fly:

```ruby
filter :name do
  fuzzy_match do |scope, value|
    # ... code ...
  end
end
```

This supports `filter[name][fuzzy_match]=foo`.

#### Filter Options {#filter-options}

| Option | Description |
| --- | --- |
| `only`, `except` | Limit the operators generated from the type's defaults, e.g. `filter :name, :string, only: [:eq, :suffix]` |
| `allow` | Only permit these values, e.g. `filter :size, :string, allow: ['Big', 'Medium', 'Small']` |
| `deny` | Reject these values, e.g. `filter :size, :string, deny: ['X-Large']` |
| `single` | Accept one value instead of an array. `boolean` filters are `single: true` by default. |
| `required` | Reject the request if the filter is absent, e.g. `filter :customer_id, :string, required: true` (equivalently, `attribute :customer_id, :integer, filterable: :required`) |
| `dependent` | Require other filters alongside this one, e.g. `filter :customer_id, :integer, dependent: [:customer_type]` paired with `filter :customer_type, :string, dependent: [:customer_id]`, so querying by id requires type, and vice versa |
| `allow_nil` | Coerce an incoming `null` to Ruby `nil` instead of the string `"null"`. Default `false`. Set `self.filters_accept_nil_by_default = true` on a Resource to flip it for all of that Resource's filters. |

```ruby
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
```

#### Boolean Filter {#boolean-filter}

Filters with type `boolean` are `single: true` by default. A boolean filter accepting multiple values doesn't make sense.

#### Hash Filter {#hash-filter}

Filters with type `hash` parse JSON automatically when passed in a URL query string:

```ruby
# GET /employees?filter[metadata]={ "foo": 100 }

filter :metadata, :hash do
  eq do |scope, value|
    value # => [{ "foo" => 100 }]
  end
end
```

#### Escaping Values {#escaping-values}

By default, Graphiti parses a comma-delimited string as an array. Wrap a value in `{{curlies}}` to keep it intact, for a "keyword search" field that could itself contain a comma:

```ruby
# GET /employees?filter[keywords]={{some,value}}

filter :keywords, :string do
  eq do |scope, value|
    value # => "some,value"
  end
end
```

Or define an array explicitly instead of relying on comma-splitting:

```ruby
# GET /employees?filter[keywords]=[some,value]

filter :keywords, :string do
  eq do |scope, value|
    value # => ["some", "value"]
  end
end
```

A `single: true` filter skips array parsing entirely and escapes the value for you, filtering on the string as given.

### Statistics {#statistics}

```ruby
stat total: [:count]
stat rating: [:average]
stat likes: [:sum]
stat score: [:maximum]

stat rating: [:average] do
  standard_deviation do |scope, attr|
    # your standard deviation code here
  end
end
```

Every Resource has a `total: :count` statistic by default. Statistics respect filtering but not pagination, so you can show a "Total Posts" count above a paginated grid without a second request:

```ruby
PostResource.all({
  stats: { total: 'count' }
})
# GET /posts?stats[total]=count
```

```ruby
{
  meta: {
    stats: {
      total: {
        count: 100
      }
    }
  }
}
```

### Extra Fields {#extra-fields}

```ruby
extra_attribute :net_worth
```

Works like `attribute`, except the field is read-only and only returned when explicitly requested: `?extra_fields[employees]=net_worth`.

Adjust the scope (e.g. to eager-load) only when the extra field is requested:

```ruby
resource.on_extra_attribute :net_worth do |scope|
  scope.includes(:assets)
end
```

### #resolve {#resolve}

`#resolve` must execute the query and return an array of `Model` instances. Override it to add behavior around the default:

```ruby
def resolve(scope)
  Rails.logger.info "begin resolving scope..."
  result = super
  Rails.logger.info "resolved!"
  result
end
```

## Configuration {#configuration}

```ruby
class PostResource < ApplicationResource
  self.model = Post
  self.type = 'posts'

  # Only used if you care about Links
  primary_endpoint '/posts', [:index, :show, :create, :update, :destroy]

  self.default_sort = [{ title: :asc }]  # default nil
  self.default_page_size = 10             # default 20
end
```

Typically inherited from `ApplicationResource`, where cross-cutting settings live:

```ruby
class ApplicationResource < Graphiti::Resource
  # Required when there's no corresponding model
  self.abstract_class = true

  # Subclasses override as needed
  self.adapter = Graphiti::Adapters::ActiveRecord

  # Default attribute flags. See #limiting-behavior
  self.attributes_readable_by_default = true
  self.attributes_writable_by_default = true
  self.attributes_sortable_by_default = true
  self.attributes_filterable_by_default = true

  # Used for link generation
  self.base_url = Rails.application.routes.default_url_options[:host]
  # Suggest referencing this in config/routes.rb:
  #   scope path: ApplicationResource.endpoint_namespace do
  #     resources :posts
  #   end
  self.endpoint_namespace = '/api/v1'

  # Raise if a Resource is accessed from a URL it isn't allowlisted for
  self.validate_endpoints = false

  # Automatically generate JSONAPI links?
  self.autolink = true
end
```

### Polymorphic Resources {#polymorphic-resources}

Polymorphic Resources are similar to [ActiveRecord STI](https://api.rubyonrails.org/classes/ActiveRecord/Inheritance.html): a single query returns multiple Resource types. Querying `/tasks` can return `bugs`, `features`, and `epics`.

```ruby
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
```

```ruby
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
```

`/tasks` returns [JSONAPI types](http://jsonapi.org/format/#document-resource-identifier-objects) of `bugs`, `features`, and `epics`. Only `features` render `points`. Only `epics` render the `milestones` relationship. `/tasks?include=milestones` correctly only queries and renders Milestones for Epics.

Resources connect to each other through relationships. See [Relationships](/concepts/relationships).

## Generators {#generators}

```bash
$ rails generate graphiti:resource NAME [attribute:type] [options]
```

```bash
$ rails generate graphiti:resource Employee first_name:string age:integer
```

Adds a route, controller, resource, and tests.

Limit the actions the resource supports with `-a`:

```bash
$ rails generate graphiti:resource Employee -a index show
```

Writing data (creating, updating, and destroying resources, including a graph of them in a single request) is covered in [Persisting](/concepts/persisting).

## Context {#context}

```ruby
# app/resources/post_resource.rb
attribute :active, :boolean, writable: :admin?

def admin?
  context.current_user.admin?
end
```

Every Resource has access to `#context`. Under Rails, `context` is the controller instance processing the request.

Put common helpers like `current_user` on `ApplicationResource`, so every Resource can call them:

```ruby
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
```

Set context manually with `with_context`:

```ruby
ctx = OpenStruct.new(current_user: User.first)
Graphiti.with_context(ctx) do
  # current_user == ctx.current_user
  PostResource.all
end
```

## Concurrency {#concurrency}

Under Rails, concurrency turns on by default when `::Rails.application.config.cache_classes` is `true` (the default for staging and production). Sibling sideloads then load concurrently, so a `Post` sideloading `Comments` and `Author` loads both at the same time. Your initializer runs after that default lands, so it always has the last word. That cuts both ways, since an unconditional `c.concurrency = true` forces it on everywhere, development and test included.

```ruby
# config/initializers/graphiti.rb
Graphiti.configure do |c|
  # c.concurrency = false
  c.concurrency_max_threads = ENV.fetch("GRAPHITI_CONCURRENCY_MAX_THREADS", 4).to_i
end
```

Sideloads share a pool of `concurrency_max_threads` threads (default 4) per process. Whatever the request thread knew, the sideload knows too. `Graphiti.context`, fiber-locals and `ActiveSupport::CurrentAttributes` all carry over so `Current.user` works inside a sideload. Assignments made inside a sideload don't travel back.

### Sizing the connection pool {#concurrency-pool-sizing}

Every thread talking to the database holds its own connection, and concurrent sideloads are extra threads. The connection pool has to cover both.

```yaml
# database.yml
pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5).to_i + 4 + 1 %>
```

That's web threads plus `concurrency_max_threads` plus a spare. Rails uses the same rule for its [async query executor](https://guides.rubyonrails.org/configuring.html#config-active-record-async-query-executor), and the default of 4 comes from there too.

When the pool is too small you get `ActiveRecord::ConnectionTimeoutError` ("all pooled connections were in use"). It only shows up once traffic is heavy enough to drain the pool, so an undersized app can run happily for months. (So check `database.yml` and make sure `pool` reads the variable your deploys actually set.)

The pool that drains is ActiveRecord's connection pool. Web threads and concurrent sideload threads all draw from it, which is why the formula above adds `concurrency_max_threads`. Shrinking `concurrency_max_threads` is always safe. When Graphiti's pool fills up, extra sideloads just run on the request thread on its already-counted connection, so you lose some parallelism and nothing else. Raising it is what needs care, since every sideload thread is one more claim on connections, and the formula has to grow with it.

The database server has its own ceiling, `max_connections` in Postgres. Every Ruby process brings a full pool, so weigh that limit against your process count, meaning Puma `workers` (`WEB_CONCURRENCY`) times your server count, plus each job worker process, all multiplied by `pool`.

`bin/rake graphiti:audit` checks the formula against this environment's numbers.

The analysis behind these numbers is in [#469](https://github.com/graphiti-api/graphiti/issues/469), worth reading in full if you're debugging connection errors.

## Adapters {#adapters}

Common resource overrides can be packaged into an Adapter for code re-use, most commonly to use a different client/datastore than ActiveRecord/RelationalDB.

[Adapters are best explained in the 'Without ActiveRecord' recipe](/topics/without-activerecord).
