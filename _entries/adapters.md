---
sectionid: adapters
sectionclass: h2
title: Adapters
number: 28
parent-id: customize
---

If you simply want to provide sensible defaults, define an adapter:

```ruby
class SequelAdapter < JsonapiCompliable::Adapters::Abstract
  def filter(db, attribute, value)
    db.where(attribute => value)
  end

  def order(db, attribute, direction)
    if direction == :asc
      db.order_append(attribute)
    else
      db.order_append(Sequel.desc(attribute)
    end
  end

  def paginate(db, current_page, per_page)
    db.paginate(current_page, per_page)
  end

  def count(scope, attr)
    db.count
  end

  # etc.
end
```

```ruby
class EmployeeResource < JsonapiCompliable::Resource
  type :employees
  use_adapter SequelAdapter
end
```

We could now do something like `render_jsonapi(DB[:employees])`
