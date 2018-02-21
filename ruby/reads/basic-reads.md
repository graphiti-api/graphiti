---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Basic Reads

Here's the full code for a JSONAPI endpoint that supports sorting,
pagination, sparse fieldsets and a [JSONAPI-compliant](http://jsonapi.org/format/#document-structure) response:

{% highlight ruby %}
# app/models/post.rb
class Post < ApplicationRecord
end
{% endhighlight %}

{% highlight ruby %}
# config/routes.rb
scope path: '/api' do
  scope path: '/v1' do
    resources :posts, only: [:index]
  end
end
{% endhighlight %}

{% highlight ruby %}
# app/serializers/serializable_post.rb
class SerializablePost < JSONAPI::Serializable::Resource
  type :posts

  attribute :title
  attribute :description
  attribute :body
end
{% endhighlight %}

{% highlight ruby %}
# app/resources/post_resource.rb
class PostResource < ApplicationResource
  type :posts
  model Post
end
{% endhighlight %}

{% highlight ruby %}
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  jsonapi resource: PostResource

  def index
    posts = Post.all
    render_jsonapi(posts)
  end
end
{% endhighlight %}

Let's walk through each of these files:

* **app/models/post.rb**
  * Our [Model](https://martinfowler.com/eaaCatalog/domainModel.html). As Martin Fowler puts it, "*An object model of the domain that incorporates both behavior and data.*". In this case we're using [ActiveRecord](http://guides.rubyonrails.org/active_record_basics.html), though other model patterns can be used. This is the **M** of [MVC](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller).

* **config/routes.rb**
  * Sets up the endpoint `/api/v1/posts`, per [Rails Routing](http://guides.rubyonrails.org/routing.html).

* **app/serializers/serializable_post.rb**
  * Given a `Model`, how do we want to represent that model as JSON? We
    might want to avoid exposing certain attributes, normalize values,
or compute something specific to the view. This is the **V** of [MVC](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller).
  * We use the excellent [jsonapi-rb](http://jsonapi-rb.org) library for
    serialization. If you're familiar with [active_model_serializers](https://github.com/rails-api/active_model_serializers), this code will look very familiar.

* **app/resources/post_resource.rb**
  * A `Resource` holds the logic for querying and persisting our
    `Model`s based on the JSONAPI request. [Learn about Resources
here]({{site.github.url}}/ruby/reads/resources).

* **app/controllers/posts_controller.rb**
  * This is a typical [Rails Controller](http://guides.rubyonrails.org/action_controller_overview.html), the **C** of [MVC](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller).
  * We've added `jsonapi resource: PostResource` to tell our controller
    to use query and persistence logic defined in our [Resource]({{site.github.url}}/ruby/resources).

All of this leads up to the all-important `render_jsonapi` method.

#### render_jsonapi

> [View the YARD documentation](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Base.html#render_jsonapi-instance_method)

This method does two things: builds and resolves the "base scope", and passes relevant options to the serialization layer.

In other words, this lower-level code would be the equivalent:

{% highlight ruby %}
scope = jsonapi_scope(Post.all) # build up the scope
posts = scope.resolve # fire the query
render json: posts,
  fields: params[:fields].split(','),
  bunch: 'of',
  other: 'options'
{% endhighlight %}

* We've started with a base scope - `Post.all` - and passed it into our
  [Resource]({{site.github.url}}/ruby/resources), which will
  modify the scope based on incoming parameters.
* We've passed a number of boilerplate options to the underlying
  [jsonapi-rb](http://jsonapi-rb.org) serialization library.

There are times we want to manually build and resolve the scope prior to
calling `render_jsonapi`. The `show` action is one example.

#### The `#show` action


Our [#show action](http://guides.rubyonrails.org/routing.html#crud-verbs-and-actions) fetches one specific post by ID, rather than a list of posts. To accomodate this, we manually build and resolve the scope instead of applying the default logic in `#render_jsonapi`:

{% highlight ruby %}
scope = jsonapi_scope(Post.where(id: params[:id]))
post = scope.resolve.first
render_jsonapi(post, scope: false)
{% endhighlight %}

Note the `scope: false` option - we've already resolved our models, so
we tell `render_jsonapi` not to run the scoping logic again.

> [View the YARD documentation for #jsonapi_scope](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Base.html#jsonapi_scope-instance_method)

It's a common convention in Rails to return a `404` response code from
the `show` action when a record is not found. Typically you'd raise and
rescue `ActiveRecord::RecordNotFound`...but we want to be agnostic to
the database. Instead:

{% highlight ruby %}
raise JsonapiCompliable::Errors::RecordNotFound unless post
{% endhighlight %}

{% highlight ruby %}
# app/controllers/application_controller.rb
rescue_exception JsonapiCompliable::Errors::RecordNotFound,
  status: 404
{% endhighlight %}

We're throwing an exception, and using our [error handling
library]({{site.github.url}}/ruby/error-handling) to
customize the status code when that particular error is thrown.
