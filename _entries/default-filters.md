---
sectionid: default-filters
sectionclass: h2
title: Default Filters
parent-id: reads
number: 10
---

Use `default_filter` in your resource when you want to apply a base
scope without user parameters. Maybe we should only show 'active'
employees by default:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  default_filter :active do |scope|
    scope.where(active: true)
  end
end
```

Default filters can be overridden when the corresponding filter is sent
in the query parameters:

```
/employees?filter[active]=false
```

Would override the default filter and show all inactive employees.
