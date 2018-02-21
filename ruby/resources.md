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

render json: posts # Finally!
{% endhighlight %}

In other words...it'd be a gross mess, especially when dealing with
[inclusion of related
resources](http://jsonapi.org/format/#fetching-includes) or swapping
datastores. But the basic pattern - starting with a scope and then
decorating it based on incoming parameters - is incredibly powerful.

Instead of writing this code by hand every time, let's move the
boilerplate into a library and leave developers only thinking about how
to modify the scope:

{% highlight ruby %}
allow_filter :title do |scope, value|
  scope.where(title: value)
end

sort do |att, dir|
  scope.order(att => dir)
end
{% endhighlight %}

This code lives in a `Resource`. All we're doing here is specifying [Procs](http://ruby-doc.org/core-2.1.1/Proc.html) that modify the scope, leaving boilerplate to the underlying `jsonapi_suite` library.

The important thing is: **you still have full control of the query**.
This is why JSONAPI Suite can easily work with any datastore, from SQL
to MongoDB to HTTP requests.

We can go even further. In the example above, you'd see the same code
over and over again for every endpoint that uses `ActiveRecord`. We
could instead build an [Adapter]({{ site.github.url }}/ruby/alternate-datastores/adapters) to
[DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) up this
code even more:

{% highlight ruby %}
allow_filter :title
{% endhighlight %}

But still allow developers to drop down to the lower-level when they need
custom logic:

{% highlight ruby %}
allow_filter :title_prefix do |scope, value|
  scope.where(["title LIKE ?", "#{value}%"])
end
{% endhighlight %}

The same basic premise applies to write operations as well. Rather than
dealing with parsing the incoming payload and associating the graph of
objects, Suite supplies hooks for just the parts you care about:
actually persisting objects.

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

There's more to learn about various ways `Resource`s can be customized,
but that's the basic premise: no magic, just removal of boilerplate.

> Note: the same `Resource` logic can be re-used across endpoints, to
> support logic like "fetch this `Post` and its `Comment`s that are
> `active`". Whether you're sideloading comments from the `/posts`
> endpoint or accessing the `/comments` endpoint directly, the same
> `Resource` logic applies.

> See the [Resource](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html) documentation for more.
