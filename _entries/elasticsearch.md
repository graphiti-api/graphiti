---
sectionid: elasticsearch
sectionclass: h2
title: ElasticSearch
number: 29
parent-id: customize
---

Here's an example of customizing using the elasticsearch gem [trample](https://github.com/richmolj/trample):

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
  end

  def index
    search = jsonapi_scope(Search::Employee.new)
    search.query!

    render_jsonapi(scope.resolve, scope: false)
  end
end
```
