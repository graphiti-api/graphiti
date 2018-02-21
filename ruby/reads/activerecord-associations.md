---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### ActiveRecord Associations

> [View the Sample App](https://github.com/jsonapi-suite/employee_directory/compare/step_9_associations...step_12_fsp_associations)

> [Understanding Nested Queries]({{site.github.url}}/ruby/reads/nested}})

JSONAPI Suite comes with an `ActiveRecord` adapter. Though other
adapters can mimic this same interface, here's what you'll get
out-of-the-box. The SQL here is roughly the same as using [#includes](http://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations).

> Note: make sure to whitelist associations in your [serializers]({{site.github.url}}/ruby/reads/serializers) or nothing will render!

#### has_many

{% highlight bash %}
/posts?include=comments
{% endhighlight %}

{% highlight ruby %}
# app/resources/post_resource.rb
has_many :comments,
  scope: -> { Comment.all },
  resource: CommentResource,
  foreign_key: :post_id
{% endhighlight %}

#### belongs_to

{% highlight bash %}
/comments?include=posts
{% endhighlight %}

{% highlight ruby %}
# app/resources/comment_resource.rb
belongs_to :post,
  scope: -> { Post.all },
  resource: PostResource,
  foreign_key: :post_id
{% endhighlight %}

#### has_one

{% highlight bash %}
/posts?include=detail
{% endhighlight %}

{% highlight ruby %}
# app/resources/post_resource.rb
has_one :detail,
  scope: -> { PostDetail.all },
  resource: PostDetailResource,
  foreign_key: :post_id
{% endhighlight %}

#### has_and_belongs_to_many

{% highlight bash %}
/posts?include=tags
{% endhighlight %}

{% highlight ruby %}
# app/resources/post_resource.rb
has_and_belongs_to_many :tags,
  scope: -> { Tag.all },
  resource: TagResource,
  foreign_key: { taggings: :tag_id }
{% endhighlight %}

The only difference here is the foreign_key - we’re passing a hash instead of a symbol. `taggings` is our join table, and `tag_id` is the true foreign key.

This will work, and for simple many-to-many relationships you can move on. But what if we want to add the property `primary`, a boolean, to the `taggings` table? Since we hid this relationship from the API, how will clients access it?

As this is metadata about the relationship it should go on the meta section of the corresponding relationship object. While supporting such an approach is on the JSONAPI Suite roadmap, we haven't done so yet.

For now, it might be best to simply expose the intermediate table to the API. Using a client like [JSORM]({{site.github.url}}/js/home), the overhead of this approach is minimal.
