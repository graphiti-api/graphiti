---
sectionid: without-activerecord
sectionclass: h1
title: Usage Without ActiveRecord
number: 18
---

So far our examples have assumed you are using `ActiveRecord`, and we do
treat that as the default. But everything can be customized. The
following shows how to use the `jsonapi {  }` DSL to build up a hash
that can be passed to an alternate ORM:

```ruby
jsonapi do
  allow_filter :name do |scope, value|
    scope[:conditions] ||= {}
    scope[:conditions].merge!(name: value)
  end

  sort do |scope, att, dir|
    scope.merge!(order: { att => dir })
  end

  paginate do |scope, current_page, per_page|
    offset = (current_page - 1 ) * per_page
    scope.merge!(limit: per_page, offset: offset)
  end

  includes whitelist: :department do |scope, includes|
    scope.merge!(include: includes)
  end
end

def index
  hash = jsonapi_scope({})
  puts hash
  # {
  #   order: { id: :asc },
  #   limit: 20,
  #   offset: 0,
  #   conditions: { name: 'foo' },
  #   include: :department
  # }
end
```

And here's an example using the elasticsearch gem [trample](https://github.com/richmolj/trample):

```ruby
class EmployeesController < ApplicationController
  jsonapi do
    allow_filter :name do |scope, value|
      scope.condition(:name).eq(value)
    end

    allow_filter :name_prefix do |scope, value|
      scope.condition(:name).starts_with(value)
    end

    paginate do |scope, current_page, per_page|
      scope.metadata.pagination.current_page = current_page
      scope.metadata.pagination.per_page = per_page
      scope
    end

    sort do |scope, att, dir|
      scope.metadata.sort = [{att: att, dir: dir}]
      scope
    end

    includes whitelist: { index: :pets } do |scope, includes|
      scope.metadata.records[:includes] = includes
      scope
    end
  end

  def index
    search = jsonapi_scope(Search::Employee.new)
    search.query!

    render_ams(search.records.to_a)
  end
end
```
