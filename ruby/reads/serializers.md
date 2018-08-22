---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Serializers

> [View the Sample App](https://github.com/jsonapi-suite/employee_directory/compare/step_24_autodocumentation...custom-serialization)

> [View additional documentation at jsonapi-rb.org](http://jsonapi-rb.org)

<img style="margin: 0 auto;width:200px;display:block" src="{{site.github.url}}/assets/img/jsonapi-rb-logo.png" />

We use [jsonapi-rb](http://jsonapi-rb.org) for serialization. If you've used [active_model_serializers](https://github.com/rails-api/active_model_serializers) before, it will look incredibly familiar:

{% highlight ruby %}
# app/serializers/serializable_post.rb
class SerializablePost < JSONAPI::Serializable::Resource
  type :posts

  attribute :title
  attribute :description
  attribute :body
end
{% endhighlight %}

Would render the [JSONAPI Document](http://jsonapi.org/format/#document-structure):

{% highlight ruby %}
{
  data: {
    type: "posts",
    id: "123",
    attributes: {
      title: "My Post",
      description: "Some description",
      body: "Blah blah blah"
    }
  }
}
{% endhighlight %}

#### Associations

To add an association:

{% highlight ruby %}
has_many :comments
{% endhighlight %}

Assuming there is a corresponding `SerializableComment`, you'd see:

{% highlight ruby %}
{
  data: {
    type: "posts",
    id: "123",
    attributes: { ... },
    relationships: {
      comments: {
        data: [
          { id: "1", type: "comments" }
        ]
      }
    }
  },
  included: [
    {
      type: "comments",
      id: "1"
    }
  ]
}
{% endhighlight %}

> Note: Your `Resource` must [whitelist this sideload]({{site.github.url}}/ruby/reads/nested) as well.

#### Customizing Serializers

Occasionally you may need to normalize, format, or elsewise transform
your `Model` into an effective JSON representation. To do this, pass a
block to `attribute` and reference the underlying `@object` being
serialized:

{% highlight ruby %}
attribute :title do
  @object.title.upcase
end
{% endhighlight %}

> Why not methods like AMS? To avoid collissions with native ruby methods like `tap`.

Keep in mind all serializers have access to `@context` - the calling
controller in Rails.

#### Conditional Fields

You may want to render a field based on runtime context - for instance,
only show the `salary` field if the user is a manager. Keeping in mind
that `@context` will always be available as the calling controller:

{% highlight ruby %}
attribute :salary, if: -> { @context.current_user.manager? }
{% endhighlight %}

> [View additional documentation at jsonapi-rb.org](http://jsonapi-rb.org)

> [Visit the jsonapi-rb Gitter chatroom](https://gitter.im/jsonapi-rb)
