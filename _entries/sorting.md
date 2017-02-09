---
sectionid: sorting
sectionclass: h2
title: Sorting
parent-id: reads
number: 8
---

Use `sort` in your resource to override the sorting behavior:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees

  sort do |scope, attribute, direction|
    if direction = :seniority_level
      scope.joins(:positions).order("positions.seniority_level #{direction}")
    else
      scope.order(attribute => direction)
    end
  end
end
```

This will multisort as well, given a URL like
`/employees?sort=first_name,last_name`.

The default sort is `id ascending`. To change this:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  # ... code ...

  default_sort([{ title: :desc }])
end
```
