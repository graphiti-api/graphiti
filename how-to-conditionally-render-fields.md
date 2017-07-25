---
layout: page
---

Extra Attributes
==========

Of course, JSONAPI already has the concept of sparse fieldsets built-in.
This behavior comes out-of-the-box at URLs like
`/people?fields[people]=title,active`.

Sometimes it's necessary to conditionally render an *extra* field as
well. For instance, maybe rendering out the `net_worth` attribute is
computationally expensive and not often requested.

Let's add a simple *extra attribute*:

```ruby
# app/serializers/serializable_person.rb
extra_attribute :net_worth do
  1_000_000
end
```

This field will not be rendered when we hit `/people`. It will only be
rendered when we hit `/people?extra_fields[people]=net_worth`. The URL
signature is the same as [sparse fieldsets](http://jsonapi.org/format/#fetching-sparse-fieldsets).

We may want to eager load some data, only when a specific extra field is
requested. We can do that by customizing the `Resource`:

```ruby
# app/resources/person_resource.rb
extra_field :net_worth do |scope|
  scope.includes(:assets)
end
```

We will now eager load assets only when the `net_worth` extra field is
specified in the request.

Finally, additional conditionals can still be applied:

```ruby
# app/serializers/serializable_person.rb
extra_attribute :net_worth, if: proc { @context.allow_net_worth? } do
```

If using Rails, `@context` is your controller.

<br />
<br />

{% include highlight.html %}

