---
sectionid: basics
sectionclass: h2
title: The Basics
parent-id: reads
number: 5
---

Let's write a very simple controller:

```ruby
class EmployeesController < ApplicationController
  jsonapi { }

  def index
    employees = Employee.all
    render_ams(employees)
  end
end
```

The above controller automatically supports:

* [Pagination](http://jsonapi.org/format/#fetching-pagination)
* [Sorting](http://jsonapi.org/format/#fetching-sorting)
* [Sparse Fieldsets](http://jsonapi.org/format/#fetching-sparse-fieldsets)
* A [jsonapi.org compatible response](http://jsonapi.org/format/#document-structure)

In other words, we now support these URLs:

* `http://localhost:3000/api/employees?page[number]=2&page[size]=1`
* `http://localhost:3000/api/employees?sort=-name`
* `http://localhost:3000/api/employees?fields[employees]=name,age`

Let's take a look at what this code does.

`jsonapi { }` sets up our controller. We'll go into this in more detail
later.

`render_ams` is similar to `render :json`. However, it's going to do
some extra work for you. For starters, it will pass relavant arguments -
like which sparse fieldsets were requested - to `render` for you.

`render_ams` will also build the appropriate query scope. In this case
we passed it an ActiveRecord scope (`Employee.all`) that can be chained
off of. In this case we're automatically adding pagination, sorting, and
`select` to that scope.

This means you could optionally provide a default scope:

```ruby
def index
  employees = Employee.where(active: true)
  render_ams(employees)
end
```

If you want to lower-level access to the scope we're building, use
`jsonapi_scope`. The following is equivalent:

```ruby
def index
  scope = jsonapi_scope(Employee.all)
  scope = scope.where(active: true)

  # Here we'll pass the actual records instead of
  # a scope, the scoping logic has already fired.
  render_ams(scope.to_a)
end
```
