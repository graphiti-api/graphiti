---
sectionid: filtering
sectionclass: h2
title: Filtering
parent-id: reads
number: 6
---

Let's have some fun implementing [filtering](http://jsonapi.org/format/#fetching-filtering).

Assume we're using ActiveRecord and want to filter records based on name
and email:

```ruby
class EmployeesController < ApplicationController
  jsonapi do
    allow_filter :name
    allow_filter :email
  end
  # ... code ...
end
```

Congratulations! You can now filter on name, email, or both. In other
words, these URLs now work:

* `/api/employees?filter[name]=Homer`
* `/api/employees?filter[email]=chunkylover53@hotmail.com`
* `/api/employees?filter[name]=Homer&email=chunkylover53@hotmail.com`

What if you want to filter on something that's not an attribute, like
all names starting with 'hom'? Simply pass a block to `allow_filter` and
chain onto your scope:

```ruby
allow_filter :name_prefix do |scope, value|
  scope.where(["name LIKE ?", "#{value}%"])
end
```

Or maybe we're using [acts_as_taggable_on](https://github.com/mbleigh/acts-as-taggable-on) and want to find all employees with a given tag:

```ruby
allow_filter :tag do |scope, value|
  scope.tagged_with(value, any: true)
end
```

Filters can be conditional as well. Let's say we want to allow filtering
on `salary` if the user is an admin:

```ruby
allow_filter :salary, if: :admin?

# ... code ...

def admin?
  current_user.role == 'admin'
end
```

{::options parse_block_html="true" /}
<div class='note info'>
###### Customizing Filters
  <div class='note-content'>
  There are a number of ways to customize filters. To see full
  documentation, check out [jsonapi_compliable](https://github.com/jsonapi-suite/jsonapi_compliable).
  </div>
</div>
<div style="height: 7rem" />
