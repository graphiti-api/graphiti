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

#### polymorphic_belongs_to

{% highlight ruby %}
# app/models/employee.rb
belongs_to :workspace, polymorphic: true
{% endhighlight %}

{% highlight ruby %}
# app/models/workspace.rb
has_many :employees, as: :workspace
{% endhighlight %}

{% highlight ruby %}
# app/resources/employee_resource.rb
polymorphic_belongs_to :workspace,
  group_by: :workspace_type,
  groups: {
    'Office' => {
      scope: -> { Office.all },
      resource: OfficeResource,
      foreign_key: :workspace_id
    },
    'HomeOffice' => {
      scope: -> { HomeOffice.all },
      resource: HomeOfficeResource,
      foreign_key: :workspace_id
    }
  }
{% endhighlight %}

{% highlight bash %}
/employees?include=workspace
{% endhighlight %}

Here an `Employee` belongs to a `Workspace`. `Workspace`s have
different `type`s - `HomeOffice`, `Office`, `CoworkingSpace`, etc. The
`employees` table has `workspace_id` and `workspace_type` columns
to support this relationship.

We may need to query each `workspace_type` differently - perhaps
they live in separate tables (`home_offices`, `coworking_spaces`, etc). So, when fetching the relationship, we'll need to group our `Employees` by `workspace_type` and query differently for each group:

{% highlight ruby %}
# app/resources/employee_resource.rb
polymorphic_belongs_to :workspace,
  group_by: :workspace_type,
  groups: {
    'Office' => {
      scope: -> { Office.all },
      resource: OfficeResource,
      foreign_key: :workspace_id
    },
    'HomeOffice' => {
      scope: -> { HomeOffice.all },
      resource: HomeOfficeResource,
      foreign_key: :workspace_id
    }
  }
{% endhighlight %}

Let's say our API was returning 10 `Employees`, sideloading their corresponding `Workspace`. The underlying code would:

* Fetch the employees
* Group the employees by the given key: `employees.group_by { |e|
  e.workspace_type }`
* Use the `Office` configuration for all `Employee`s where
  `workspace_type` is `Office`, and use the `HomeOffice` configuration
for all `Employee`s where `workspace_type` is `HomeOffice`, and so
forth.
