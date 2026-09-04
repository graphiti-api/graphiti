---
title: 'Step 5'
---

### Step 5: Has One

> [View the Diff](https://github.com/graphiti-api/employee_directory/compare/step_4_customizations...step_5_has_one)

In the last step, we introduced the concept of a "current position" to
the model layer. Let's now expose that relationship to the API.

### The Rails Stuff 🚂

We already defined a `Position.current` scope that we'll re-use -
let's just make a small tweak to support the opposite use case as
well:

```ruby
scope :current, ->(bool) {
  clause = { historical_index: 1 }
  bool ? where(clause) : where.not(clause)
}
```

### The Graphiti Stuff 🎨

You might already have an idea how this might work from the prior step
- we'll use the `params` block to customize the relationship. The `has_one` macro ensures the result is treated as a single object and
not an array.

```ruby
# app/resources/employee_resource.rb
has_one :current_position, resource: PositionResource do
  params do |hash|
    hash[:filter][:current] = true
  end
end
```

Which means we'll have to implement that filter - re-using the
ActiveRecord scope we already defined!

```ruby
filter :current, :boolean do
  eq { |scope, value| scope.current(value) }
end
```

#### Digging Deeper 🧐

In this example, we're able to return only a single record because we
have a `historical_index` column. If this column didn't exist - maybe we're just ordering on `created_at` and taking the first record - we'd
have a problem. What if we were loading 20 employees and wanted the
`current_position` of each - what SQL would limit the resultset
correctly?

We call this a [faux has_one](/concepts/relationships#faux-has-one) and there's nothing easily done here. Graphiti will ensure only one record
is returned by the API, but the query will take longer and loading extra
records will eat memory. If there are lots of records in the
association, look into adding a column like `historical_index`.


  <h2 id="next">
    <a href="/tutorial/step_6">
      NEXT - 
      <small>Step 6: Customizing Writes</small>
      &raquo;
    </a>
  </h2>
