---
title: 'Usage Without ActiveRecord'
---

# Usage Without ActiveRecord
Graphiti was built to be used with any ORM or datastore, from PostgreSQL
to elasticsearch to `Net::HTTP`. In fact, Graphiti itself is tested with
Plain Old Ruby Objects (POROs).

This cookbook will show how to customize a resource around a particular datastore, and how to package those
customizations into a reusable adapter. We'll use an in-memory datastore
and Plain Old Ruby Objects (POROs) here, but the lessons apply to any
datastore.

For working code, see [this branch of the sample application](https://github.com/graphiti-api/employee_directory/blob/poro/app/resources/post_resource.rb).

We'll start with this PORO model:

```ruby
class Post
  # Define getters/setters
  # e.g. post.title = 'foo'
  ATTRS = [:id, :title]
  ATTRS.each { |a| attr_accessor(a) }

  # Instantiate with hash of attributes
  # e.g. Post.new(title: 'foo')
  def initialize(attrs = {})
    attrs.each_pair { |k,v| send(:"#{k}=", v) }
  end

  # This part only needed for our particular
  # persistence implementation; you may not need it
  # e.g. post.attributes # => { title: 'foo' }
  def attributes
    {}.tap do |attrs|
      ATTRS.each do |name|
        attrs[name] = send(name)
      end
    end
  end
end
```

And this in-memory datastore:

```ruby
# If we were working with more than just Posts, we'd need a 'type'
# field here as well, to simulate a table name.
DATA = [
  { id: 1, title: 'Graphiti' },
  { id: 2, title: 'is' },
  { id: 3, title: 'super' },
  { id: 4, title: 'dope' }
]
```

## Resource Overrides {#resource-overrides}

If it's your first time with a new ORM or datastore, we recommend
putting the logic in the Resource first. Once things are working *and*
there are multiple uses of the same overrides, package them into an
Adapter.

```ruby
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
```

Here we're using the `Null` adapter, which acts as a dumb pass-through.
This can be helpful when you just want to get running for a simple use
case and don't want errors around features you haven't implemented yet.
But it can also be confusing when you expect certain codepaths to
be hit. Mostly just be aware of `Null`'s behavior, or use `Graphiti::Adapters::Abstract` to get helpful errors around what's not
implemented.

We're also supplying an explicit `base_scope`. This is the beginning
query object we'll modify as params come in. In the case of
ActiveRecord, we might want an `ActiveRecord::Relation` like `Post.all`. For our example, we'll modify a simple ruby hash (keep in
mind the premise of building a hash of options and passing it off to a
client can apply to any datastore).

Finally, we're [resolving that scope](/concepts/resources#resolve),
returning the full dataset for now. The contract of `#resolve` is to return an array of model instances, hence `DATA.map { |d| Post.new(d)
}`.

#### Sorting {#sorting}

```ruby
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
```

We modified the base scope with a default hash key, `:sort`. When the
user requests sorting, we record this by merging into the hash. We can
then reference that information on the scope when resolving.

Note the `sort_all` scope block, in fact all scope blocks, must return the scope.

#### Paginating {#paginating}

```ruby
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
```

Again: merge into the scope, then reference the scope data when
resolving.

#### Filtering {#filtering}

```ruby
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
```

Same as above examples. Again, we must return the scope object
from the filter function.

#### Persisting {#persisting}

All at once:

```ruby
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
```

These are the overrides for persistence operations. You are encouraged
**not** to override `create/update/destroy` directly and instead use
[Persistence Lifecycle Hooks](/concepts/persisting#persistence-lifecycle-hooks).

## Adapters {#adapters}

OK so we have all our read and write operations working correctly. But
if we had multiple Resources all using an in-memory datastore, you'd see
this logic repeated all over the place. Let's create an adapter to [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
up this logic.

There isn't much more to do than copy/paste what we've already done.
Let's start with our `base_scope`, sorting, and pagination:

```ruby
class POROAdapter < Graphiti::Adapters::Abstract
  def base_scope(*)
    { sort: {}, filters: {} }
  end

  def paginate(scope, current, per)
    scope.merge!(current_page: current, per_page: per)
  end

  def order(scope, att, dir)
    scope[:sort].merge!(attribute: att, direction: dir)
    scope
  end

  def resolve(scope)
    data = DATA
    if sort = scope[:sort].presence
      data = data.sort_by { |d| d[sort[:attribute].to_sym] }
      data = data.reverse if sort[:direction] == :desc
    end
    start = (scope[:current_page] - 1) * scope[:per_page]
    stop  = start + scope[:per_page]
    data  = data[start...stop]

    data.map { |d| resource.model.new(d) }
  end
end
```

There's really nothing here we haven't seen before. We're taking the
code we originally wrote, and sticking it into the interface defined by
`Graphiti::Adapters::Abstract`.

There's a *little* more to do with filtering:

```ruby
def filter(scope, attribute, value)
  scope[:filters][attribute] = value
  scope
end
alias :filter_string_eq :filter
alias :filter_integer_eq :filter
alias :filter_date_eq :filter
# ... etc ...
```

The logic is the same, but we have a separate method for each filter
operator. This allows us to query differently based on the type - for
instance, ActiveRecord will default to case-insensitive for strings, but
straight equality for integers. If you don't need operator-specific
logic, just `alias` as you see here.

You may want to limit the default operators we expect to work with a
given type. Let's say your backend allows straight equality for strings,
but doesn't support `prefix`, `suffix`, etc. You can specify this in
your adapter:

```ruby
def self.default_operators
  super.tap do |built_in|
    built_in[:string] = [:eq]
  end
end

# or avoid super altogether

def self.default_operators
  {
    string: [:eq],
    integer: [:eq]
    # ... etc ...
  }
end
```

**That's it for reads**. For writes, I'll post the entire adapter code
below - again, it's just copy/pasting what we already wrote into a
slightly different format.

```ruby
def destroy(model)
  Post::DATA.reject! { |d| d[:id].to_s == model.id.to_s }
  model
end

def save(model)
  attrs = model.attributes.dup
  attrs[:id] ||= Post::DATA.length + 1
  if existing = Post::DATA.find { |d| d[:id].to_s == attrs[:id].to_s }
    existing.merge!(attrs)
  else
    Post::DATA << attrs
  end
  model
end

# For wrapping persistence operations in a DB transactions
# Our in-memory DB doesn't have transactions, so just yield
def transaction(*)
  yield
end
```

That's really it. [See the working code in Employee Directory here](https://github.com/graphiti-api/employee_directory/blob/poro/app/resources/post_resource.rb).
