---
layout: page
---

Statistics
==========

Imagine a grid listing records. What if we want "X total records",
above that grid, or "average cost" elsewhere in our UI?

These calculations are supported via `allow_stat`:

```ruby
# app/resources/employee_resource.rb
allow_stat total: [:count]
```

A GET to `/api/employees?stats[total]=count` would return:

```ruby
{
  data: [...],
  meta: {
    stats: {
      total: {
        count: 100
      }
    }
  }
}
```

A few 'default calculations' are provided: `count`, `sum`, `average`,
`maximum` and `minimum`. These will work out-of-the-box with `ActiveRecord`.
Alternatively, override these calculation functions:

```ruby
allow_stat :salary do
  average { |scope, attr| scope.average(attr) }
end
```

Or support your own custom calculations:

```ruby
allow_stat salary: [:average] do
  standard_deviation { |scope, attr| ... }
end
```

Multiple stats are supported with one request:

```ruby
GET /api/employees?stats[salary]=average,maximum&stats[total]=count
```

If you want **only** stats, and no records (for performance), simple pass page size 0:

`GET /api/employees?stats[salary]=average&page[size]=0`

<br />
<br />

{% include highlight.html %}
