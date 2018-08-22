---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Relationships and Nested Queries

> [View the JSONAPI Specification](http://jsonapi.org/format/#fetching-includes)

> [View the Sample App](https://github.com/jsonapi-suite/employee_directory/compare/step_9_associations...step_12_fsp_associations)

> [View the JS Documentation]({{site.github.url}}/js/reads/nested-queries)

Let's say we want to fetch a `Post` and all of its `Comment`s:

{% highlight bash %}
/posts?include=comments
{% endhighlight %}

Using the default `ActiveRecord` Adapter, we would add this code to our
`PostResource`:

{% highlight ruby %}
# app/resources/post_resource.rb
has_many :comments,
  scope: -> { Comment.all },
  resource: CommentResource,
  foreign_key: :post_id
{% endhighlight %}

> Note: we'd have to whitelist `comments` in our [serializer]({{ site.github.url }}/ruby/reads/serializers) as well.

To understand this code, we first have to realize that this is a Macro -
code that is generating lower-level code for the purposes of removing
boilerplate. Let's understand the lower-level DSL before breaking
down the macro.

{% highlight ruby %}
allow_sideload :comments, resource: CommentResource do
  scope do |posts|
    # ... code ...
  end

  assign do |posts, comments|
    # ... code ...
  end
end
{% endhighlight %}

This is the lower-level `allow_sideload` DSL. There are four things
going on. To begin with:

* We've whitelisted `comments`. Without this, the request would raise
  the error `JsonapiCompliable::Errors::InvalidInclude`. This ensures
  clients can't arbitrarily pull back data that could introduce performance
  problems or security risks.
* We've said, "when retrieving comments, re-use the logic defined in
  `CommentResource`". This way all the filter, sorting, etc query logic
at the `/comments` endpoint can be reused when sideloading comments from
the `/posts?include=comments` endpoint.

That brings us to the `scope` and `assign` hooks. When querying a
relationship, we need to answer two questions:

* Given a list of parents (`post`s), how should we scope the request for
children (`comment`s)? This is the `scope` block. In a relational
database, we'd usually scope based on foreign and primary keys.
* Given a list of parents (`post`s) and a list of children (`comment`s),
how do you want to assign these objects together? This is the `assign`
block. In a relational database, we'd usually compare foreign and
primary keys.

In other words, the code would look similar to this for `ActiveRecord`:

{% highlight ruby %}
scope do |posts|
  Comment.where(post_id: posts.map(&:id))
end

assign do |posts, comments|
  posts.each do |post|
    post.comments = comments.select { |c| c.post_id == post.id }
  end
end
{% endhighlight %}

Note that `scope` hasn't actually fired a query - we take the result of
this block and pass it to `CommentResource` so that further query logic
(filtering, sorting, etc) can be applied and re-used across endpoints.

Of course, the code above would be very tedious to write by hand every
time. That's why we have Macros like `has_many`, `belongs_to` etc -
configure only the parts you need, and avoid the boilerplate:

{% highlight ruby %}
# app/resources/post_resource.rb
has_many :comments,
  scope: -> { Comment.all },
  resource: CommentResource,
  foreign_key: :post_id
  # primary_key defaults to 'id'
{% endhighlight %}

Given the above options, we can auto-generate `allow_sideload` code. You
can always write `allow_sideload` directly if you have highly customized
logic. You can also pass a block to the macros to customize:

{% highlight ruby %}
# app/resources/post_resource.rb
has_many :comments,
  scope: -> { Comment.all },
  resource: CommentResource,
  foreign_key: :post_id do
    assign do |posts, comments|
      # some custom code to associate these objects
      Post.associate(posts, comments)
    end
  end
{% endhighlight %}

Again, nested queries come for free. This code allows for nested queries
like "give me the post, and its `active` comments":

{% highlight bash %}
/posts/1?include=comments&filter[comments][active]=true
{% endhighlight %}
