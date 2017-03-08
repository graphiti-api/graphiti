---
sectionid: resource-dsl
sectionclass: h2
title: Resource DSL
number: 27
parent-id: customize
---

So far our examples have used `ActiveRecord`, but everything can be customized. The
following shows the various 'entry points' to customize scoping rules.
Note that each block must return a 'scopeable' that will be passed on:

```ruby
jsonapi do
  allow_filter :name do |scope, value|
    # ... custom scoping ...
    # Default: scope.where(name: value)
  end

  paginate do |scope, current_page, per_page|
    # ... custom pagination ...
    # Default: scope.per(per_page).page(current_page)
  end

  sort do |scope, att, dir|
    # ... custom pagination ...
    # Default: scope.per(per_page).page(current_page)
  end

  allow_sideload :things, resource: ThingResoure do
    scope do |parents|
      # ... custom sideload scope ...
      # Default: N/A
    end

    assign do |parents, children|
      # ... custom sideload assignment ...
      # Default: N/A
    end
  end

  # Default: 20
  default_page_size(10)

  # Default: [{ id: :asc }]
  default_sort([{ title: :asc }])

  # Custom resolve function
  # by default, delegates to adapter
  def resolve(scope)
    # This is the ActiveRecord default
    scope.to_a
    # Or, let's say our scope is a built-up hash we want to pass to
    # an HTTP client:
    MyExternalService.call(scope)
  end
end
```
