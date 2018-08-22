---
layout: page
---

Usage Without ActiveRecord: ElasticSearch
==========

Though we'll be hitting [elasticsearch](https://www.elastic.co) in this
example, remember that this is just an HTTP API underneath the hood. The
same pattern applies to a variety of use cases.

First we need a **Client** for `elasticsearch`. Though you can feel free
to use a variety of clients, this example will use [trample](http://richmolj.github.io/trample).

Though we'll show code snippets below, feel free to [view the diff on
github](https://github.com/jsonapi-suite/employee_directory/compare/step_23_disassociation...elasticsearch).

Also keep in mind, we'll be showing a one-off customization here. You
probably want to extract this code into an `Adapter` if this is going to
become a core component of your application.

Start by installing trample:

{% highlight ruby %}
# Gemfile
gem 'trample_search', require: 'trample'
{% endhighlight %}

Tell [searchkick](https://github.com/ankane/searchkick) that we want to
index `Employee`s and `Position`s:

{% highlight ruby %}
# app/models/employee.rb
searchkick text_start: [:first_name]

# app/models/position.rb
searchkick text_start: [:title]
{% endhighlight %}

Define our search classes. These tell trample the configuration of the
search:

{% highlight ruby %}
# app/models/employee_search.rb
class EmployeeSearch < Trample::Search
  model Employee

  condition :first_name, single: true
  condition :last_name, single: true
end

# app/models/position_search.rb
class PositionSearch < Trample::Search
  model Position

  condition :title, single: true
  condition :employee_id
end
{% endhighlight %}

In our controller, we need to pass a base scope. Before, we were passing
an `ActiveRecord::Relation` (`Post.all`). Let's pass an instance
of `Trample::Search` instead. Since by default search results come back
as `Hashie::Mash`es, we'll also specify our serializer directly. You
could also use a generic `SearchResult` serializer, it's up to you.

{% highlight ruby %}
# app/controllers/employees_controller.rb
def index
  render_jsonapi EmployeeSearch.new,
    class: SerializableEmployeeSearchResult
end
{% endhighlight %}

{% highlight ruby %}
# app/serializers/serializable_employee_search_result.rb
class SerializableEmployeeSearchResult < JSONAPI::Serializable::Resource
  type :employees

  attribute :first_name
  attribute :last_name
  attribute :created_at
  attribute :updated_at

  has_many :positions, class: 'SerializablePositionSearchResult'
end
{% endhighlight %}

Since we are now passing a non-default base scope, we need to tell our
`Resource` how to query and resolve this new scope. Start by switching to
the pass-through adapter, and resolve using `trample`'s query API:

{% highlight ruby %}
# app/resources/employee_resource.rb
use_adapter JsonapiCompliable::Adapters::Null
# ... code ...
def resolve(scope)
  scope.query!
  scope.results
end

# remove the belongs_to for now
{% endhighlight %}



You can now hit `http://localhost:3000/api/v1/employees` - the exact
same payload is coming back, but is now sourced from `elasticsearch`!

Let's add a prefix filter:

{% highlight ruby %}
# app/resources/employee_resource.rb
allow_filter :first_name_prefix do |scope, value|
  scope.condition(:first_name).starts_with(value)
end
{% endhighlight %}

Hit `http://localhost:3000/api/v1/employees?filter[first_name]=hom`.
You're now successfully querying the `elasticsearch` index.

 If we want sorting and pagination, we need to tell the `Resource`
 how to deal with that, too:

{% highlight ruby %}
# app/resources/employee_resource.rb
paginate do |scope, current_page, per_page|
  scope.metadata.pagination.current_page = current_page
  scope.metadata.pagination.per_page = per_page
  scope
end

sort do |scope, att, dir|
  scope.metadata.sort = [{att: att, dir: dir}]
  scope
end
{% endhighlight %}

View the [Resource](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html) and [Adapter](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Adapters/Abstract.html) documentation for additional overrides, like statistics.

The last step is adding the `positions` association. If we want
`has_many`-style macros we need to create an `Adapter`, but for now
let's simply use the lower-level `allow_sideload` DSL. We need to define
two functions: how to build a scope for the association, and how to
associate the resulting objects:

{% highlight ruby %}
# app/resources/employee_resource.rb
allow_sideload :positions, resource: PositionResource do
  scope do |employees|
    scope = PositionSearch.new
    scope.condition(:employee_id).or(employees.map(&:id))
  end

  assign do |employees, positions|
    employees.each do |e|
      e.positions = positions.select { |p| p.employee_id = e.id }
    end
  end
end
{% endhighlight %}

Convert the `PositionResource` to use `elasticsearch`, just like we did
for `Employee`:

{% highlight ruby %}
# app/resources/position_resource.rb
use_adapter JsonapiCompliable::Adapters::Null

def resolve(scope)
  scope.query!
  scope.results
end
{% endhighlight %}

Create the `SerializablePositionSearchResult` class that we referenced
in `app/serializers/serializable_employee.rb`:

{% highlight ruby %}
class SerializablePositionSearchResult < JSONAPI::Serializable::Resource
  type :positions

  attribute :title
end
{% endhighlight %}

We can now sideload `positions` - check out the results at
`http://localhost:3000/api/v1/employees?include=positions`. We're
fetching employees and their corresponding `positions` in a single
request, via `elasticsearch`. Any filters/changes/default sort/etc that
apply to `PositionResource` can be re-used at this endpoint.

If this was a one-off section of our application, we can call this good
enough and move on. But as we continue to use this pattern, it's going
to get monotonous writing the same filter overrides, `allow_sideload`
wiring code, etc. To DRY up this code, we can package our changes into
an [Adapter](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Adapters/Abstract.html).
