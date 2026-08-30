---
id: intro
title: 'Graphiti'
sidebar_label: 'Overview'
sidebar_position: 0
slug: /
---

# Graphiti

Graphiti is a serialization (and de-serialization) library for Ruby, with integrations for Rails included.

It's built on the [JSON:API](https://jsonapi.org) spec, which settles the decisions every API accumulates: response shapes, filtering, sorting, pagination, error formats, and how related data rides along. Your client layer (often a javascript single page app) speaks this protocol in return. It isn't complicated, so client logic can be hand-rolled or you can use one of the [many available libraries](https://jsonapi.org/implementations/#client-libraries) that work with the standard.

This is an alternative to a library like JBuilder, which builds each JSON response individually.

Graphiti sits on top of your models and exposes them over a JSON:API-compliant interface. You define Resources instead of controllers and serializers, and get filtering, sorting, pagination, sparse fieldsets, statistics, and nested reads and writes across relationships, all over one endpoint.

Here is the whole loop. A Resource declares what's exposed:

```ruby title="app/resources/employee_resource.rb"
class EmployeeResource < ApplicationResource
  self.model = Employee # usually inferred from the class name, here for clarity

  attribute :first_name, :string
  attribute :last_name, :string
  attribute :age, :integer

  has_many :positions
end
```

The controller hands it the request params and renders the result:

```ruby title="app/controllers/employees_controller.rb"
class EmployeesController < ApplicationController
  def index
    employees = EmployeeResource.all(params)

    respond_to do |format|
      format.jsonapi { render(jsonapi: employees) }
      format.json    { render(json: employees) }
      format.xml     { render(xml: employees) }
    end
  end

  def show
    employee = EmployeeResource.find(params)
    authorize employee.data # data is the Employee model, authorize is Pundit
    render(jsonapi: employee)
  end
end
```

A client asks for employees and their positions in one request:

```http title="Request"
GET /api/v1/employees?include=positions
```

```json title="Response"
{
  "data": [
    {
      "id": "1",
      "type": "employees",
      "attributes": {
        "first_name": "Jane",
        "last_name": "Doe",
        "age": 34
      },
      "relationships": {
        "positions": {
          "data": [
            { "type": "positions", "id": "1" },
            { "type": "positions", "id": "2" }
          ]
        }
      }
    }
  ],
  "included": [
    {
      "id": "1",
      "type": "positions",
      "attributes": { "title": "Engineer" }
    },
    {
      "id": "2",
      "type": "positions",
      "attributes": { "title": "Senior Engineer" }
    }
  ]
}
```

That same Resource also serves `?filter[age][gt]=30`, `?sort=-age`, `?page[size]=10`, `?fields[employees]=first_name`, and `?stats[total]=count`, without writing any of them.

The same proxy renders all three formats, so `/employees.jsonapi`, `/employees.json` and `/employees.xml` all work off one action.

`.all` and `.find` return that proxy, so nothing has been queried yet. `.data` is where you reach the model, and also where per-record authorization goes. See [Authorization](/topics/authorization#integrating-with-pundit).

If repeating that `respond_to` block gets old, the optional [`responders`](https://github.com/heartcombo/responders) integration collapses it to `respond_with(employees)`. See [Installation](/getting-started/installation#responders).

## The whole Resource API

Every Resource is a collection of defaults, and you can override any of them. Below is one Resource with those defaults written out the long way, the entire surface area on a single page. You wouldn't write this much by hand. It's here so you can see what's available.

### ApplicationResource

Every Resource inherits from an `ApplicationResource`, the same way models inherit from `ApplicationRecord`. This is where cross-cutting configuration lives, so individual Resources stay small. It's also the right place to put helpers like `current_user`, which guards throughout your API can then call.

```ruby title="app/resources/application_resource.rb"
class ApplicationResource < Graphiti::Resource
  # Required when there's no corresponding model
  self.abstract_class = true

  # Subclasses override as needed
  self.adapter = Graphiti::Adapters::ActiveRecord

  # Flip any of these to lock down every Resource at once,
  # e.g. a read-only API
  self.attributes_readable_by_default = true
  self.attributes_writable_by_default = true
  self.attributes_sortable_by_default = true
  self.attributes_filterable_by_default = true

  # Used for link generation
  self.base_url = ENV.fetch('BASE_URL', 'http://localhost:3000')
  self.endpoint_namespace = '/api/v1'

  def current_user
    context.current_user
  end
end
```

### A Resource

An individual Resource declares its attributes and relationships, plus anything about it that differs from the defaults:

```ruby
class EmployeeResource < ApplicationResource
  # Both inferred from the class name. Set them only when they differ
  self.model = Employee
  self.type = :employees # the JSONAPI type

  self.default_sort = [{ name: :desc }] # default nil
  self.page_default_size = 10           # default 20

  attribute :name, :string
  attribute :age, :integer
  attribute :hired_at, :datetime, writable: false

  has_many :positions
end
```

That is a complete, working Resource. Everything below is how you override a piece of it.

### Attributes

```ruby
# Each flag defaults to the corresponding class-level setting
attribute :name, :string,
  readable: self.attributes_readable_by_default,
  writable: self.attributes_writable_by_default,
  sortable: self.attributes_sortable_by_default,
  filterable: self.attributes_filterable_by_default

# Alter display
# @object is your model instance
attribute :name, :string do
  @object.name.upcase
end
```

### Sorting

```ruby
# Pass a type - sort :name, :string - if no attribute is defined
sort :name do |scope, dir|
  scope.order(name: dir)
end
```

### Filtering

```ruby
# Pass a type - filter :name, :string - if no attribute is defined
filter :name do
  # All of these operators have not_ equivalents, e.g. not_eq
  # Imagine ".where.not" instead of ".where"

  eq do |scope, value|
    scope.where("lower(name) IN ?", value.map(&:downcase))
  end

  eql do |scope, value|
    scope.where(name: value)
  end

  prefix do |scope, value|
    value.each do |v|
      scope = scope.where('lower(name) LIKE ?', "#{v.downcase}%")
    end
    scope
  end

  suffix do |scope, value|
    value.each do |v|
      scope = scope.where('lower(name) LIKE ?', "%#{v.downcase}")
    end
    scope
  end

  match do |scope, value|
    value.each do |v|
      scope = scope.where('lower(name) LIKE ?', "%#{v.downcase}%")
    end
    scope
  end
end

# Comparison operators, for integer, float, datetime, etc
filter :age, :integer do
  eq do |scope, value|
    scope.where(age: value)
  end

  gt do |scope, value|
    value.each { |v| scope = scope.where('age > ?', v) }
    scope
  end

  gte do |scope, value|
    value.each { |v| scope = scope.where('age >= ?', v) }
    scope
  end

  lt do |scope, value|
    value.each { |v| scope = scope.where('age < ?', v) }
    scope
  end

  lte do |scope, value|
    value.each { |v| scope = scope.where('age <= ?', v) }
    scope
  end
end
```

Filters receive an array of values by default, which is why each operator above iterates. Pass `single: true` to accept one value instead.

### Querying

```ruby
# Passed to sort, filter, paginate, etc
# Apply global logic here: only return active Employees,
# scope results to the current user, and so on
def base_scope
  Employee.all
end

# Must execute the query and return an array of Model instances
def resolve(scope)
  scope.to_a
end
```

### Persisting

Your adapter handles writes for you, so most Resources define nothing here. Reach for [lifecycle hooks](/concepts/persisting#persistence-lifecycle-hooks) when you need to intervene:

```ruby
before_attributes do |attributes|
  # before attributes are assigned to the model
end

before_save do |model|
  # assigned, but not yet persisted
end

before_commit do |model|
  # saved and validated, still inside the transaction
end
```

The model you inspect is the model that saves. Attributes are assigned up front, so you can hold the model, check it, and change it before anything is written. The instance you were handed is the one that gets persisted:

```ruby
employee = EmployeeResource.build(payload)

employee.data           # the model, attributes already assigned, nothing written yet
employee.data.valid?    # inspect it, or modify it
employee.save           # persists that same instance
```

Updates work the same way, reading the persisted record until you apply the payload:

```ruby
proxy = EmployeeResource.find(payload)
proxy.data.first_name       # => "asdf", straight from the database
proxy.assign_attributes(payload)
proxy.data.first_name       # => "Jane", assigned but still unsaved
proxy.save(action: :update)
```

## Upgrading from 1.x

The [2.0 upgrade guide](/upgrading) covers the whole migration: the three gems that folded into core, the deprecated spellings that still work but warn, and the two real behavior changes. Controllers now opt in via `Graphiti::Rails::Controller`, and `around_persistence` receives the model rather than an attributes hash.
