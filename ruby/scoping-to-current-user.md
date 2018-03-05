---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Scoping to Current User

> Given a `Post` model with `hidden` attribute, only allow administrators
to view hidden `Posts`.

Let's start by adding a `visible` scope to `Post`, so we can easily
retrive only `Post`s where `hidden` is `false`:

{% highlight ruby %}
# app/models/post.rb
scope :visible, -> { where(hidden: false) }
{% endhighlight %}

As you know, we would typically use the base scope `Post.all` like so:

{% highlight ruby %}
def index
  render_jsonapi(Post.all)
end
{% endhighlight %}

Let's instead use the base scope `Post.visible` when the user is not an
administrator:

{% highlight ruby %}
def index
  scope = current_user.admin? ? Post.all : Post.visible
  render_jsonapi(scope)
end
{% endhighlight %}

That's it! Now only administrators can view hidden `Post`s.

Of course, this logic would only apply to the `/posts` endpoint and
would not apply when we are sideloading from `/blogs?include=posts`. To
ensure this logic runs *all the time*, add a default filter:

{% highlight ruby %}
default_filter :visible do |scope, context|
  context.current_user.admin? ? scope : scope.visible
end
{% endhighlight %}

### <a name="privileged-writes" href='#privileged-writes'>Privileged Writes</a>

> Given `Post`s that have an `internal` attribute, only allow
internal users to publish internal posts.

Our controller context is available in our resource. Let's override
`Resource#create` to ensure correct privileging:

{% highlight ruby %}
def create(attributes)
  if !internal_user? && attributes[:internal] == true
    raise "Hey you! YOU can't publish internal posts!"
  else
    super
  end
end

private

def internal_user?
  context.current_user.internal?
end
{% endhighlight %}

### <a name="guarding-filters" href='#guarding-filters'>Guarding Filters</a>

> Given `Employee`s with attribute `under_performance_review`, do not allow clients to find all employees under performance review.

Occasionally you need to guard filters based on the current user. Use
the `:if` option on `allow_filter`. This will execute in the context of
your controller:

{% highlight ruby %}
# app/resources/employee_resource.rb
allow_filter :under_performance_review, if: :admin?
{% endhighlight %}

{% highlight ruby %}
# app/controllers/employees_controller.rb
class EmployeesController < ApplicationController
  jsonapi resource: EmployeeResource

  def index
    render_jsonapi(Employee.all)
  end

  private

  def admin?
    current_user.admin?
  end
end
{% endhighlight %}

