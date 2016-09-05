---
sectionid: includes
sectionclass: h2
title: Includes
parent-id: reads
number: 7
---

[Inclusion of related resources](http://jsonapi.org/format/#fetching-includes) (*'sideloading'*) is critical to JSON API. We need to do three things to support this feature:

* Render the requested resources in `included`.
* Make sure our ORM eager loads all relationships to avoid N+1 issues.
* Whitelist certain includes. You probably don't want to expose your
entire object graph, for both performance and security concerns.

The suite will handle this for you. Just add a whitelist:

```ruby
jsonapi do
  includes whitelist: { index: 'tags' }
end
```

No other code changes are required. Our endpoint now supports
`/api/employees?include=tags`, putting all `Tag` resources in `included`. Any resources requested that have not been whitelisted will be silently dropped.

Nesting includes is also supported:

```ruby
jsonapi do
  includes whitelist: { index: ['tags', { department: 'goals' }] }
end
```

Would support the endpoint
`/api/employees?include=tags,department.goals`. This is why the
whitelist is a hash - you may want to limit the whitelist for `index`
for performance reasons:

```ruby
jsonapi do
  includes whitelist: {
    index: :department,
    show: ['tags', { department: 'goals' }] }
  }
end
```

{::options parse_block_html="true" /}
<div class='note info'>
###### Ensure your serializer specifies relationships
  <div class='note-content'>
  The above code assumes relationships are specified in your serializers
  as well. Our `EmployeeSerializer` would need:

```ruby
belongs_to :department
has_many :tags
```
  </div>
</div>
<div style="height: 15rem" />
