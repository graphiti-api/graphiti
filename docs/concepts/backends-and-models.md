---
title: 'Backends and Models'
---

# Backends and Models

A Resource queries a **Backend** and returns **Models** from what comes back. Graphiti serializes the Models.

With ActiveRecord those are the same object. `Employee` is both the thing you query and the thing you render, and you can skip most of this page. It matters when they're separate: a search index, an HTTP service, a document store. Then the Backend is whatever you query, and the Model is whatever you hand back.

## Scopes {#scopes}

A **scope** is whatever your backend needs to run a query. Graphiti doesn't care what it is. For ActiveRecord it's an `ActiveRecord::Relation`. Here it's a plain hash:

```ruby
class EmployeeResource < ApplicationResource
  self.adapter = Graphiti::Adapters::Null

  attribute :name, :string

  def base_scope
    { conditions: {}, sort: {} }
  end

  filter :name do
    eq do |scope, value|
      scope[:conditions].merge!(value)
      scope
    end
  end

  sort :name do |scope, direction|
    scope[:sort] = { name: direction }
    scope
  end

  def resolve(scope)
    results = Backend.query(scope)
    results.map { |result| Employee.new(result) }
  end
end
```

`base_scope` is the starting point, each `filter` and `sort` block mutates it based on request params, and `resolve` runs the query and returns Models.

**Every block must return the scope.** Returning the result of `merge!` or an assignment instead of the scope itself is the most common way to break this.

Writing that per Resource gets old. Once the pattern stabilizes, move it into an [Adapter](/topics/without-activerecord#adapters) and Resources go back to being declarative:

```ruby
class EmployeeResource < ApplicationResource
  self.adapter = BackendAdapter
  attribute :name, :string
end
```

## What a Model has to do {#model-requirements}

**Respond to `id`, uniquely.** Graphiti uses `model.id` to tell records apart when rendering. Duplicate ids produce wrong output, not an error.

If the underlying record has no id, generate one:

```ruby
def id
  @id ||= SecureRandom.uuid
end
```

**Respond to its readable attributes.** `attribute :name, :string` calls `model.name`. If your Model doesn't have that method, pass a block instead:

```ruby
attribute :name, :string do
  @object.full_name
end
```

**Include `ActiveModel::Validations` if you want validation errors.** Graphiti checks models on write requests and renders a [JSON:API errors payload](http://jsonapi.org/format/#errors) from `model.errors`. Without it, an invalid model saves silently:

```ruby
class Employee
  include ActiveModel::Validations

  validates :name, presence: true
end
```

## Writing a Model {#model-implementations}

Graphiti has no opinion here. A plain class works:

```ruby
class Employee
  attr_accessor :id, :first_name, :last_name, :age

  def initialize(attrs = {})
    attrs.each_pair { |key, value| send(:"#{key}=", value) }
  end
end
```

[ActiveModel::Model](https://api.rubyonrails.org/classes/ActiveModel/Model.html) gives you the constructor and validations for free:

```ruby
class Employee
  include ActiveModel::Model

  attr_accessor :id, :first_name, :last_name, :age
end
```

[Dry::Struct](https://dry-rb.org/gems/dry-struct) adds type enforcement, and dry-types is already a Graphiti dependency:

```ruby
class Employee < Dry::Struct
  attribute :id, Types::Integer
  attribute :first_name, Types::String
  attribute :last_name, Types::String
  attribute :age, Types::Integer
end
```

`OpenStruct` also works and is what Graphiti uses internally for remote resources, but it fails quietly in ways the others don't. See [OpenStruct Models](/topics/openstruct-models) before reaching for it.
