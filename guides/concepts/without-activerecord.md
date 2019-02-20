---
layout: page
---

Usage Without ActiveRecord
==========================

Graphiti was build to be used with any ORM or datastore, from PostgreSQL
to elasticsearch to `Net::HTTP`. In fact, Graphiti itself is tested with
Plain Old Ruby Objects (POROs).

This guide will show how to customize a resource around a particular datastore, and how to package those
customizations into a reusable adapter.

For working code, see [this branch of the sample application](https://github.com/graphiti-api/employee_directory/blob/poro/app/resources/post_resource.rb).

We'll start with this PORO model:

{% highlight ruby %}
class Post
  def initialize(attrs = {})
    attrs.each_pair { |k,v| send(:"#{k}=", v) }
  end

  ATTRS = [:id, :title]
  ATTRS.each { |a| attr_accessor(a) }

  # This part only needed for our particular
  # persistence implementation; you may not need it
  def attributes
    {}.tap do |attrs|
      ATTRS.each do |name|
        attrs[name] = send(name)
      end
    end
  end
end
{% endhighlight %}

And this in-memory datastore:

{% highlight ruby %}
DATA = [
  { id: 1, title: 'Graphiti' },
  { id: 2, title: 'is' },
  { id: 3, title: 'super' },
  { id: 4, title: 'dope' }
]
{% endhighlight %}

## Resource Overrides

If it's your first time with a new ORM or datastore, we recommend
putting the logic in the Resource first. Once things are working *and*
there are multiple uses of the same overrides, package them into an
Adapter.

{% highlight ruby %}
class PostResource < ApplicationResource
  self.adapter = Graphiti::Adapters::Null

  attribute :title, :string

  def base_scope
    {}
  end

  def resolve(scope)
    DATA.map { |d| Post.new(d) }
  end
end
{% endhighlight %}

Here we're using the `Null` adapter, which acts as a dumb pass-through.
This can be helpful when you just want to get running for a simple use
case and don't want errors around features you haven't implemented yet.
But it can also be confusing when you expect certain codepaths to
be hit. Mostly just be aware of `Null`'s behavior, or use
`Graphiti::Adapters::Abstract` to get helpful errors around what's not
implemented.

We're also supplying an explicit `base_scope`. This is the beginning
query object we'll modify as params come in. In the case of
ActiveRecord, we might want an `ActiveRecord::Relation` like
`Post.all`. For our example, we'll modify a simple ruby hash.

Finally, we're [resolving that scope](/graphiti/guides/concepts/resources#resolve),
returning the full dataset for now. The contract of `#resolve` is to
return an array of model instances, hence `DATA.map { |d| Post.new(d)
}`.

#### Sorting

{% highlight ruby %}
sort_all do |scope, attribute, direction|
  scope[:sort].merge!(attribute: att, direction: dir)
end

def base_scope
  { sort: {} }
end

def resolve(scope)
  if sort = scope[:sort].presence
    data = DATA.sort_by { |d| d[sort[:attribute].to_sym] }
    data = data.reverse if sort[:direction] == :desc
  end
  DATA.map { |d| Post.new(d) }
end
{% endhighlight %}

We modified the base scope with a default hash key, `:sort`. When the
user requests sorting, we record this by merging into the hash. We can
then reference that information on the scope when resolving.

Note the `sort_all` scope block, in fact all scope blocks, must return the scope.

#### Paginating

{% highlight ruby %}
paginate do |scope, current_page, per_page|
  scope.merge!(current_page: current, per_page: per)
end

def resolve(scope)
  # ... sorting ...
  start = (scope[:current_page] - 1) * scope[:per_page]
  stop  = start + scope[:per_page]
  data  = data[start...stop]
  # ... return models ...
end
{% endhighlight %}

Again: merge into the scope, then reference the scope data when
resolving.

#### Filtering

{% highlight ruby %}
filter :title, only: [:eq] do
  eq do |scope, value|
    scope[:filters][attribute] = value
    scope
  end
end

def base_scope(*)
  { sort: {}, filters: {} }
end

def resolve(scope)
  # ... sorting ...
  scope[:filters].each_pair do |k, v|
    data = data.select { |d| d[k.to_sym].in?(v) }
  end
  # ... pagination ...
  # ... return models ...
end
{% endhighlight %}

Same as above examples. Again, note that we must return the scope object
from the filter function.

##### Persisting

All at once:

{% highlight ruby %}
# Instantiate a model for #create
def build(model_class)
  model_class.new
end

# Used for create/update
def assign_attributes(model, attributes)
  attributes.each_pair do |k, v|
    model.send(:"#{k}=", v)
  end
end

# Used for create/update
def save(model)
  attrs = model.attributes.dup
  attrs[:id] ||= DATA.length + 1
  if existing = DATA.find { |d| d[:id].to_s == attrs[:id].to_s }
    existing.merge!(attrs)
  else
    DATA << attrs
  end
  model
end

# Used for destroy
def delete(model)
  DATA.reject! { |d| d[:id].to_s == model.id.to_s }
  model
end
{% endhighlight %}

These are the overrides for persistence operations. You are encouraged
**not** to override `create/update/destroy` directly and instead use
[Persistence Lifecycle Hooks]({{site.github.url}}/concepts/resources#persistence-lifecycle-hooks).

## Adapters

Coming soon...
