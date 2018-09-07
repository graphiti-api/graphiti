---
layout: page
---

Tutorial
==========

### Step 4: Customizing Queries

So far, we've done fairly straightforward queries. If a user filters on
`first_name`:

`/api/v1/employees?filter[first_name]=Foo`

We'll query the equivalent database column:

{% highlight ruby %}
Employee.where(first_name: 'Foo')
{% endhighlight %}

But what if there's more complex logic? Let's say we want to sort
Employees on their `title` - which comes from the `positions` table.
How would that work?

#### Rails

First, we need to get data for an Employee's **current** position.
Let's start by defining what `current` means

{% highlight ruby %}
# app/models/position.rb
scope :current, -> { where(historical_index: 1) }
{% endhighlight %}

> See the [ActiveRecord Scopes](https://guides.rubyonrails.org/active_record_querying.html#scopes) documentation if you're unfamiliar with this concept.

Reference this scope in a new association:

{% highlight ruby %}
has_one :current_position,
  -> { current },
  class_name: 'Position'
{% endhighlight %}

Before moving on, let's review what we need to do. The `ActiveRecord`
code for sorting Employees on their current position's title would be:

{% highlight ruby %}
Employee.joins(:current_position).merge(Position.order(title: :asc))
{% endhighlight %}

Let's wire this up to Graphiti:

#### Graphiti

We're only going to **sort** and **filter** on the `title` attribute -
never display or pesist. So start by defining the attribute as such:

{% highlight ruby %}
attribute :title, :string, only: [:filterable, :sortable]
{% endhighlight %}

Then the `sort` DSL to define custom sorting logic:

{% highlight ruby %}
# app/resources/employee_resource.rb

sort :title do |scope, direction|
  scope.joins(:current_position).merge(Position.order(title: direction))
end
{% endhighlight %}

That's it! When a request to sort on the title comes in, we'll alter our
scope to join on the `positions` table, and order based on the current
position `title`.

The solution for filtering is similar:

{% highlight ruby %}
# app/resources/employee_resource.rb

filter :title do
  eq do |scope, value|
    scope.joins(:current_position).merge(Position.where(title: value))
  end
end
{% endhighlight %}

We can now filter on title:

`/api/v1/employees?filter[title]=Foo`

<!--TODO section: filter primary data by association-->
<!--TODO section: filter associated data-->
