---
title: 'Step 6'
---

### Step 6: Customizing Writes

> [View the Diff](https://github.com/graphiti-api/employee_directory/compare/step_5_has_one...step_6_write_customization)

When we ran the generators (and created a blank Resource class), we got the ability to create, update, and destroy resources for free. You can turn off this behavior with `self.read_only = true`. Or for relationships: `has_many :positions, writable: false`.

But in RESTful APIs, it's super common for persistence operations to
have side effects - that's how we avoid extraneous verbs and
inconsistent patterns.

In a prior step, we updated `position` Factory to automatically reorder the `historical_index`: when a new record comes in, all the prior
values need to change. This step will show how to add that behavior to
our API, using hooks that work for a variety of scenarios: sending
emails, checking authorization roles, queuing delayed jobs, and more.

### The Rails Stuff 🚂

Previously, we put the logic that re-ordered the `historical_index` column in the `position` factory. Let's move that to the model so our
tests and API can share the same logic:

```ruby
# app/models/position.rb
def self.reorder!(employee_id)
  scope = Position.where(employee_id: employee_id).order(created_at: :desc)
  scope.each_with_index do |p, index|
    p.update_attribute(:historical_index, index + 1)
  end
end
```

```ruby
# spec/factories/positions.rb
# ... code ...
after(:create) do |position|
  unless position.historical_index
    Position.reorder!(position.employee.id)
  end
end
```

### The Graphiti Stuff 🎨

All Graphiti updates happen within a transaction. We want to insert our
code right before that transaction closes - after the graph of objects
has been persisted and validations have passed. To do that, we'll use
the `before_commit` hook:

```ruby
before_commit only: [:create, :destroy] do |position|
  Position.reorder!(position.employee_id)
end
```

Again, the `Position.reorder!` code existed independent of our
API, and was re-used in our factory.

#### Digging Deeper 🧐

Resources come with [Lifecycle Hooks](https://www.graphiti.dev/guides/concepts/persisting#persistence-lifecycle-hooks), similar to ActiveRecord [Callbacks](https://guides.rubyonrails.org/active_record_callbacks.html).

Those callbacks have gotten a bad reputation. This is because your Model
can be - is supposed to be - used in a variety of contexts across your
application. Some of those contexts will want a given callback to fire,
others will not, and accomodating the conditionals gets hairy. This is
why many developers move that functionality into [Service Objects](https://engineering.gusto.com/the-rails-callbacks-best-practices-used-at-gusto/).

But Resource callbacks don't have the same problem - they only fire in
the context of your API, and can be associated to a single endpoint. You
can still use Service Objects if you'd like. Graphiti callbacks wire them up.


  <h2 id="next">
    <a href="/tutorial/step_7">
      NEXT - 
      <small>Step 7: Many to Many</small>
      &raquo;
    </a>
  </h2>
