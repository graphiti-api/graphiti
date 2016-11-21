---
sectionid: customize
sectionclass: h1
title: Customize
number: 19
is-parent: true
---

So far our examples have assumed you are using `ActiveRecord`, and we do
treat that as the default. But everything can be customized. The
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

  includes whitelist: { index: :pets } do |scope, includes|
    # ... custom eager loads ...
    # Default: scope.includes(includes)
  end
end
```

Define `default_page_size` if you'd prefer something other than `20`:

```ruby
class PostsController < ApplicationController
 jsonapi do
   # ... code ...
 end

 def default_page_size
   100
 end
end
```
