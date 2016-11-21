---
sectionid: without-kaminari
sectionclass: h3
title: Usage without Kaminari
parent-id: customize
number: 20
---

Any pagination scheme can be used. The following shows how to customize using `will_paginate` instead of the default Kaminari:

```ruby
jsonapi do
  paginate do |scope, current_page, per_page|
    scope.paginate(page: params[:page], per_page: 30)
  end
end
```
