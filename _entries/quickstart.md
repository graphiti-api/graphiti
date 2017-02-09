---
sectionid: quickstart
sectionclass: h1
title: Quickstart
is-parent: true
number: 4
---

Let's write a very simple controller:

```ruby
class EmployeesController < ApplicationController
  jsonapi do
    type :employees
    use_adapter JsonapiCompliable::Adapters::ActiveRecord

    allow_filter :name
  end

  def index
    employees = Employee.all
    render_jsonapi(employees)
  end
end
```

The above controller automatically supports:

* [Pagination](http://jsonapi.org/format/#fetching-pagination)
* [Sorting](http://jsonapi.org/format/#fetching-sorting)
* [Sparse Fieldsets](http://jsonapi.org/format/#fetching-sparse-fieldsets)
* [Filtering](http://jsonapi.org/format/#fetching-filtering) the 'name'
attribute.
* A [jsonapi.org compatible response](http://jsonapi.org/format/#document-structure)

In other words, we now support these URLs:

* `http://localhost:3000/api/employees?page[number]=2&page[size]=1`
* `http://localhost:3000/api/employees?sort=-name`
* `http://localhost:3000/api/employees?filter[name]=Homer`
* `http://localhost:3000/api/employees?fields[employees]=name,age`

Let's take a look at what this code does.

`jsonapi { }` sets up our controller. We'll go into this in more detail
later.

`render_jsonapi` is similar to `render :json` (actually `render :jsonapi` under-the-hood). However, it's going to do
some extra work for you. For starters, it will pass relevant arguments -
like which sparse fieldsets were requested - to `render` for you.

`render_jsonapi` will also build the appropriate query scope. In this case
we passed it an ActiveRecord scope (`Employee.all`) that can be chained
off of. In this case we're automatically adding pagination, sorting, and
`select` to that scope.

This means you could optionally provide a default scope:

```ruby
def index
  employees = Employee.where(active: true)
  render_jsonapi(employees)
end
```

If you want to lower-level access to the scope we're building, use
`jsonapi_scope`. The following is equivalent:

```ruby
def index
  # returns a JsonapiCompliable::Scope object
  scope = jsonapi_scope(Employee.all)
  # We can get lower-level access to the underlying 'scope object'
  scope.object = scope.object.where(active: true)
  # Resolve the scope to fire SQL and get actual Employee objects:
  results = scope.resolve
  # Here we'll pass the actual records instead of
  # a scope, as the scoping logic has already fired.
  render_jsonapi(results, scope: false)
end
```

{::options parse_block_html="true" /}
<div class='note info'>
###### Remember Your Serializers!
  <div class='note-content'>
  This documentation assumes you're roughly familiar with
  [jsonapi-rb](http://jsonapi-rb.org). Note the above code would not output jsonapi unless a `SerializableEmployee` is defined. By convention, we would put this in `app/serializers/serializable_employee.rb`.
  </div>
</div>
<div style="height: 8rem;" />
