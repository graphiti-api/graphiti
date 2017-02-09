---
sectionid: resource-introduction
sectionclass: h2
title: Resources
parent-id: reads
number: 6
---

A `Resource` defines a 'query chain' for a given object. Think of this
ActiveRecord code, querying for 20 active employees, sorted by name
descending:

```ruby
scope = Employee.all # no query fired
scope = scope.order(name: :desc) if order_by_name?
scope = scope.where(active: true) if only_active?
scope = scope.page(1).per(20) if paginated?
scope.to_a # query finally fires
```

In order to satisfy the dynamic nature of JSONAPI query parameters, we
want to do something similar - parse and normalize the incoming payload,
then gradually build up a scope. Let's express the above code as a
JSONAPI query:

```
/employees?sort=-name&filter[active]=true&page[number]=1&page[size]=20
```

And satisfy that query with a resource that knows how to filter, sort,
and paginate the relevant parameters:

```ruby
# app/resources/employee_resource.rb
class EmployeeResource < JsonapiCompliable::Resource
  type :employees

  allow_filter :active do |scope, value|
    scope.where(active: value)
  end

  sort do |scope, attribute, direction|
    scope.order(attribute => direction)
  end

  page do |scope, current_page, per_page|
    scope.per(per_page).page(current_page)
  end
end

# app/controllers/employees_controller.rb
class EmployeesController < ApplicationController
  jsonapi resource: EmployeeResource

  def index
    render_jsonapi(Employee.all)
  end
end
```

The above code starts with a base scope - `Employee.all` - then chains the
'active' filter, then chains the sorting criteria, then chains
pagination. Grunt work like
translating `-books` to `{ books: :desc }` is taken care of
behind-the-scenes.

The above code isn't very DRY, though - we'd repeat the same logic for
all our queryable entities. Instead, let's use an **adapter**, that will
provide sensible defaults:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  allow_filter :active
end
```

* We applied the 'ActiveRecord' adapter
* Sorting and pagination came for free
* We no longer had to pass a block to `allow_filter`

Of course, we could always override the adapter's default behavior as well.

None of this is tied to ActiveRecord - instead, let's build up a simple
hash we can pass to something else down the line:

```ruby
# app/resources/employee_resource.rb
class EmployeeResource < JsonapiCompliable::Resource
  type :employees

  allow_filter :active do |scope, value|
    scope.merge(active: value)
  end

  sort do |scope, attribute, direction|
    scope.merge(order: { attribute => direction }
  end

  page do |scope, current_page, per_page|
    scope.merge(page: current_page, per_page: per_page)
  end
end

# app/controllers/employees_controller.rb
class EmployeesController < ApplicationController
  jsonapi resource: EmployeeResource

  # The output of scope.resolve would be:
  #
  # {
  #   active: true,
  #   order: { name: :desc },
  #   page: 1,
  #   per_page: 20
  # }
  def index
    scope = jsonapi_scope({})
    results = MyService.get_results(scope.resolve.first)
    render_jsonapi(results, scope: false)
  end
end
```

Resources are quite flexible - we'll expand on their capabilities in the
following sections.
