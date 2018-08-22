---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Basic Writes

Here's the code for a JSONAPI endpoint that supports creating,
updating, and deleting resources, complete with validation errors. Keep in mind a small modification will
enable **nested** creates/updates/deletes/disassociations as well.

We'll be adding on to the code from the [Basic
Reads]({{site.github.url}}/ruby/reads/basic-reads) section.

{% highlight ruby %}
# config/routes.rb
resources :posts, only: [:create, :update, :destroy]
{% endhighlight %}

{% highlight ruby %}
# config/initializers/strong_resources.rb
StrongResources.configure do
  strong_resource :post do
    attribute title: :string
    attribute body: :string
    attribute rating: :integer
  end
end
{% endhighlight %}


{% highlight ruby %}
# app/controllers/posts_controller.rb

strong_resource :employee

before_action :apply_strong_params, only: [:create, :update]

def create
  post, success = jsonapi_create.to_a

  if success
    render_jsonapi(post, scope: false)
  else
    render_errors_for(post)
  end
end

def update
  post, success = jsonapi_update.to_a

  if success
    render_jsonapi(post, scope: false)
  else
    render_errors_for(post)
  end
end

def destroy
  post, success = jsonapi_destroy.to_a

  if success
    render json: { meta: {} }
  else
    render_errors_for(post)
  end
end
{% endhighlight %}

You'll see these controller methods all look very similar. Let's walk
through what's going on.

* `jsonapi_create/update/destroy`
  * Parses the incoming request (including nested associations) and
    delegates logic to the correct `Resource` classes.
  * Wraps everything in a transaction.
  * Handles validation errors.
* `post, success`
  * `post` is our model instance. Keep in mind, this may be an
    unpersisted instance if our request had validation errors.
  * `success` is a boolean indicating if the transaction was successful.
    Mostly used to determine if we had validation errors.
* `render_jsonapi` is explained in [Basic
  Reads]({{site.github.url}}/ruby/reads/basic-reads)
* `render_errors_for` collects any validation errors and formats them
  into a [JSONAPI-compliant errors object](http://jsonapi.org/format/#errors). This includes nested validation errors.
* `render json: { meta: {} }` (destroy only)
  * Satisfied the [JSONAPI specification](http://jsonapi.org/format/#crud-deleting-responses-200) for deletes.

We'll expand on these topics in the rest of the "Writes" section.

#### Delegating Logic to Resources

With read operations, we supply hooks, essentially asking the developer
"*How do you want to modify the scope when a sort parameter comes in? How
about when the `title` filter comes in?*".

The same logic applies to write operations - but instead of "*how do you
want to modify the scope?*" the question is "***how do you want to persist
this data***"?

{% highlight ruby %}
def create(attributes)
  puts attributes # { title: "Some Post" }
end
{% endhighlight %}

In `ActiveRecord`'s case, you can imagine the defaults look something
like this:

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

def destroy(id)
  post = Post.find(id)
  post.destroy
  post
end
{% endhighlight %}

> Note: create/update/destroy **must always** return the model instance

Similar to read operations, we package this logic into an
[Adapter]({{site.github.url}}/ruby/alternate-datastores/adapters) to
DRY-up the boilerplate.

For additional documentation:

* [#create](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html#create-instance_method)
* [#update](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html#update-instance_method)
* [#destroy](https://jsonapi-suite.github.io/jsonapi_compliable/JsonapiCompliable/Resource.html#destroy-instance_method)
