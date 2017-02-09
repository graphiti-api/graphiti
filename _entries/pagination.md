---
sectionid: pagination
sectionclass: h2
title: Pagination
parent-id: reads
number: 9
---

Use `paginate` in your resource to override the pagination behavior. The
following example shows how to use [will_paginate](https://github.com/mislav/will_paginate) instead of the default Kaminari:

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  paginate do |scope, current_page, per_page|
    scope.paginate(page: current_page, per_page: per_page)
  end
end
```
