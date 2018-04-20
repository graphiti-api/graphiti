---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Resources

> "A `Model` is to the `Database` what a `Resource` is to the `API`"

Resources might look magical at first, but they are actually just a
simple collection of a few common hooks.

Consider a traditional Rails controller:

{% highlight ruby %}
def index
  posts = Post.all
  render json: posts
end
{% endhighlight %}

Imagine if we had to implement the [JSONAPI specification](http://jsonapi.org) by hand, ensuring our endpoints supported sorting, pagination, filtering, etc. You'd start seeing something along these lines:

{% highlight ruby %}
# No query has fired yet, this is a blank ActiveRecord scope
posts = Post.all

if title = params[:filter].try(:title)
  # Alter the scope if we're filtering
  posts = posts.where(title: title)
end

# ... etc ...

if sort = params[:sort]
  # Alter the scope if we're sorting
  sort_dir = :asc
  if sort.starts_with?('-')
    sort_dir = :desc
  end
  sort_att = sort.split('-')[1]
  posts = posts.order(sort_att => sort_dir)
end

# ... etc ...

render json: posts.to_a # Finally!
{% endhighlight %}

In other words...it'd be a gross mess, especially when dealing with
[inclusion of related
resources](http://jsonapi.org/format/#fetching-includes) or swapping
datastores. But the basic pattern - starting with a scope and then
decorating it based on incoming parameters - is incredibly powerful.

Instead of writing this code by hand every time, let's move the
boilerplate into a library and leave developers with only the part they
care about - **how to modify the scope**:

{% highlight ruby %}
allow_filter :title do |scope, value|
  scope.where(title: value)
end

sort do |att, dir|
  scope.order(att => dir)
end
{% endhighlight %}

This code lives in a `Resource`. All we're doing here is specifying [Procs](http://ruby-doc.org/core-2.1.1/Proc.html) that modify the scope, leaving boilerplate to the underlying `jsonapi_suite` library.

Of course, with `ActiveRecord`, you'd see the same logic here over
and over again. Let's supply defaults to DRY up this code and end
with:

{% highlight ruby %}
# Whitelist the filter
allow_filter :title
{% endhighlight %}

...but allow developers to override those defaults whenever they'd like:

{% highlight ruby %}
allow_filter :title do |scope, value|
  scope.where(["title LIKE ?", "#{value}%"])
end

sort do |attribute, direction|
  # ... your custom sort logic ...
end
{% endhighlight %}

The important thing is: **you still have full control of the query**.
This is why JSONAPI Suite can easily work with any datastore, from SQL
to MongoDB to HTTP requests. The "behind-the-scenes defaults" are stored
in an [Adapter]({{ site.github.url }}/ruby/alternate-datastores/adapters).
Supply blocks for one-off customizations, or package them up into an
`Adapter` once those customizations become commonplace.

By default, JSONAPI Suite comes with an `ActiveRecordAdapter`.

#### Scopes - a Generic Query-Building Pattern

If you look closely at the above examples, you can see our code breaks
down into three key parts:

  * **Step 1**: Start with a "base scope" - a default query object.
  * **Step 2**: Modify that scope based on incoming parameters.
  * **Step 3**: Actually fire the query.

This pattern applies to any ORM or datastore. Let's try it with an HTTP
client that accepts a hash of options. A generic Rails controller might
look something like:

{% highlight ruby %}
def index
  # Step 1: Our "base scope"
  scope = {}

  # Step 2: Modify that scope based on the request
  if title = params[:filter].try(:[], :title)
    scope[:title] = title
  end

  # Step 3: actually fire the request + build some models
  # Post here is a PORO (plain old ruby object)
  hashes = HTTP.get('/posts', scope)
  posts = hashes.map { |attr| Post.new(attrs) }

  # render
  render json: posts
end
{% endhighlight %}

So our JSONAPI Suite equivalent would be:

{% highlight ruby %}
# Step 1: Define the base scope in the controller
def index
  base_scope = {}
  # Pass the base scope to the resource, which will
  # build + fire the query.
  #
  # Then, render the results.
  render_jsonapi(base_scope)
end
{% endhighlight %}

{% highlight ruby %}
# app/resources/post_resource.rb
#
# Step 2: Modify the scope in the Resource
allow_filter :title do |scope, value|
  scope[:title] = value
end

# Step 3: Actually fire the query
# This method must return an array of Model instances
def resolve(scope)
  hashes = HTTP.get('/posts', scope)
  hashes.map { |attr| Post.new(attrs) }
end
{% endhighlight %}

Again, you can package this logic into an [Adapter]({{ site.github.url }}/ruby/alternate-datastores/adapters) if you found yourself repeating the same logic
over and over. Adapters DRY-up Resources.

This pattern applies to sorting, pagination, statistics and such as
well - view the [Reads]({{ site.github.url }}/ruby/reads/basic-reads) documentation
for more.

#### Associations

In the prior section, we noted the 3 key parts of query building. For
associations, we need to answer 2 key questions:

  * **Question 1**: Given an array of parents, what should the "base scope" be
    in order to query only relevant children?
  * **Question 2**: Once we've resolved both the parents and the children, how do
    we associate these objects together?

Let's switch back to vanilla `ActiveRecord` for a second. We've resolved
the `Post`s and need to fetch the `Comment`s. Here's how we'd answer
these questions:

{% highlight ruby %}
allow_sideload :comments, resource: CommentResource do
  # Question 1: What's a "base scope" that will return only
  # relevant comments?
  scope do |posts|
    Comment.where(post_id: posts.map(&:id))
  end

  # Question 2: How do we assign these objects together?
  assign do |posts, comments|
    posts.each do |post|
      post.comments = comments.select { |c| c.post_id == post.id }
    end
  end
end
{% endhighlight %}

Just like in our prior sections, we can see the same logic would apply
over and over again...with some slight tweaks based on
`has_many/belongs_to`, non-standard foreign keys and such. So our
default `ActiveRecord` adapter comes with **macros** that generate this
lower-level code for us:

{% highlight ruby %}
has_many :comments,
  resource: CommentResource,
  scope: -> { Comment.all },
  foreign_key: :post_id
{% endhighlight %}

You can dig deeper into the various [ActiveRecord Association Macros here]({{ site.github.url }}/ruby/reads/activerecord-associations).

Let's go back to HTTP calls. Imagine the `CommentResource` worked just
like our HTTP-based `PostResource` from the prior section. Let's see how
those same questions would be answered:

{% highlight ruby %}
# Step 1: What's a base scope that will return only
# relevant comments?
#
# In the case of our HTTP client, the "base scope" is
# nothing more than a ruby hash.
#
# Our final query would end up something like:
#
# HTTP.get('/comments', { post_id: [1,2,3] })
scope do |posts|
  { post_id: posts.map(&:id) }
end

# Step 2: How do we assign these objects together?
# This code is unchanged from the prior example
assign do |posts, comments|
  posts.each do |post|
    post.comments = comments.select { |c| c.post_id == post.id }
  end
end
{% endhighlight %}

The key lessons here:

  * `scope` must return a "base scope" that can be further modified.
    This way we can apply additional "deep query" logic - maybe we
    want to sort these comments - and re-use the query-building code
    defined in `CommentResource`. This allows the same logic at the
    `/comments` endpoint to apply to the `/posts?include=comments`
    endpoint.
  * If you're not sure what the scope should be, look into the relevant
    `Resource`, particularly the [#resolve](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html#resolve-instance_method) method,
    to see how the query will actually be executed.
  * [Adapters]({{ site.github.url }}/ruby/alternate-datastores/adapters) can
    DRY-up this logic with `has_many`-style macros.

#### Writes

In the prior sections, we removed boilerplate and dropped down to only
the important code of scope modification. The same basic premise applies to write operations as well. Rather than
dealing with parsing the incoming payload and associating the graph of
objects, Suite supplies hooks for just the parts you care about:
**actually persisting objects**.

{% highlight ruby %}
def create(attributes)
  post = Post.new(attributes)
  post.save
  post
end

def update(attributes)
  post = Post.find(attributes.delete(:id))
  post.update_attributes(attributes)
  post
end

# ... etc ...
{% endhighlight %}

Just like reads, this logic is usually extracted into an `Adapter`, but
you can always use `super` to override, handle side effects, etc.

{% highlight ruby %}
def create(attributes)
  model = super
  Rails.logger.info "#{model.class} created with id #{model.id}!"
  model
end
{% endhighlight %}

See the [Writes]({{ site.github.url }}/writes/basic-writes) section for
more.

#### Wrapping Up

There's more to learn about various ways `Resource`s can be customized,
but that's the basic premise: no magic, just removal of boilerplate.

> Note: the same `Resource` logic can be re-used across endpoints, to
> support logic like "fetch this `Post` and its `Comment`s that are
> `active`". Whether you're sideloading comments from the `/posts`
> endpoint or accessing the `/comments` endpoint directly, the same
> `Resource` logic applies.

> See the [Resource](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html) documentation for more.
