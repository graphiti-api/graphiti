---
layout: page
---

Building an Adapter
==========

If you find yourself repeatedly making customizations to a group of
`Resource`s and seek DRYer code, package those customizations into an
`Adapter`. Here we'll be starting from a previous how-to, [How to Use
Alternate ORMs](how-to-use-without-activerecord).

You can follow along with the below code snippets, or [view the diff on
github](https://github.com/jsonapi-suite/employee_directory/compare/step_23_disassociation...elasticsearch_adapter).

Adapters are simpler than you might think. It's little more than
copy-pasting those low-level customizations into a common class.

Start by creating `lib/elasticsearch_adapter.rb`. Cut/past the sorting,
pagination, and `#resolve` overrides from `EmployeeResource` into the adapter,
turning into `def` methods along the way:

```ruby
# lib/elasticsearch_adapter.rb
class ElasticsearchAdapter
  def paginate(scope, current_page, per_page)
    scope.metadata.pagination.current_page = current_page
    scope.metadata.pagination.per_page = per_page
    scope
  end

  def order(scope, att, dir)
    scope.metadata.sort = [{att: att, dir: dir}]
    scope
  end

  def resolve(scope)
    scope.query!
    scope.results
  end
end
```

Ensure our adapter gets loaded:

```ruby
# config/initializers/jsonapi.rb
require 'elasticsearch_adapter'
```

And switch to that adapter in `EmployeeResource`:

```ruby
use_adapter ElasticsearchAdapter
```

Bounce your server. You can still hit the `/api/v1/employees` endpoint
with the same sort and paginate functionality, but the code has been
moved to an adapter.

Let's ensure our users can filter as well:

```ruby
def filter(scope, att, val)
  scope.condition(att).eq(val)
end
```

For all the methods and functionality an adapter supports, see the
[Adapter documenation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Adapters/Abstract.html).

We probably also want `has_many`-style macros to avoid writing similar
`allow_sideload` code time after time. Start by specifying where this
functionality is defined, and add a `has_many` macro:

```ruby
module Sideloading
  def has_many(association_name,
               scope:,
               resource:,
               foreign_key:,
               primary_key: :id,
               &blk)
    # our code will go here
    instance_eval(&blk) if blk
  end
end

def sideloading_module
  Sideloading
end
```

The `instance_eval` is there so we can always drop down to a lower-level
customization in our `Resource`.

We can basically cut/paste our existing sideload code and rewrite it as
variables:

```ruby
scope do |parents|
  parent_ids = parents.map { |p| p.send(primary_key) }
  scope.call.condition(foreign_key).or(parent_ids.uniq.compact)
end

assign do |parents, children|
  parents.each do |p|
    relevant_children = children.select do |c|
      c.send(foreign_key) == p.send(primary_key)
    end
    p.send(:"#{association_name}=", relevant_children)
  end
end
```

You can now remove any customizations from your `Resource` classes. You
can continue to build the adapter, adding `belongs_to`, statistics, and
more. [View the adapter documentation for the full API](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Adapters/Abstract.html).

{% include highlight.html %}
