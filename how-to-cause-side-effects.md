---
layout: page
---

Side Effects
==========

Side effects scenarios come up often. What if we want to send an email
notification every time a `Comment` is created?

It's important to note that there are three overall categories of side effects,
and each requires a different solution:

* Side effects internal to the `Model`: For example, setting a
  `published_at` attribute.
* Side effects that should only occur on a specific request: For
  example, only send an email update if we're creating a `Post` for the
  first time, at the `/posts` endpoint.
* Side effects that should occur on every *type* of request: For
example, send an email notification every time a `Comment` is created -
but not updated - whether it was created at the `/comments` endpoint or sideposted at the
`/posts` endpoint.

#### Internal Side-Effects

For the first scenario, it's OK to use `ActiveRecord` callbacks (or the
equivalent functionality in a different ORM):

{% highlight ruby %}
# app/models/user.rb
class Post < ApplicationRecord
  before_save :set_published_at,
    on: :update,
    if: :publishing?

  private

  def set_published_at
    self.published_at = Time.now
  end

  def publishing?
    status_changed? && status == 'published'
  end
end
{% endhighlight %}

#### Side-Effects on Specific Action

Just like you would with vanilla Rails, use the controller. Here we'll
only send an email to our subscribers when the `Post` is first created.
Keep in mind we could also "sidepost" `Post` objects at the `/blogs`
endpoint, but this will only fire at the `/posts` endpoint.

{% highlight ruby %}
class PostsController < ApplicationController
  def create
    post, success = jsonapi_create.to_a

    if success
      PostMailer.published_email.deliver_later
      render_jsonapi(post, scope: false)
    else
      render_errors_for(post)
    end
  end
end
{% endhighlight %}

#### Side-Effects on Every Request of a Given Type

Let's add some special logging every time we create a `Post`. Note this
will fire *every* time we create a `Post` - whether we create it at the
`/posts` endpoint or "sidepost" at the `/blogs` endpoint.

We **do not** need to worry about this side-effect in our model specs,
or rake tasks, as the functionality is only relevant to the API.

Edit your `Resource`:

{% highlight ruby %}
# app/resources/post_resource.rb
def create(attributes)
  Rails.logger.info "Post begin created by #{context.current_user.email}..."
  super
  Rails.logger.info "Success!"
end
{% endhighlight %}

{% include highlight.html %}
