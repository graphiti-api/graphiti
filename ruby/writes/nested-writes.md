---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Nested Writes

> View the Sample App: [Server](https://github.com/jsonapi-suite/employee_directory/compare/step_19_custom_persistence...step_23_disassociation) &nbsp;\|&nbsp; [Client](https://github.com/jsonapi-suite/employee-directory-vue/compare/step_9_dropdown...step_10_nested_create)

Nested writes occur via "sideposting". Using the same example from the
[strong resources section]({{site.github.url}}/ruby/writes/strong-resources), let's "sidepost" a `Person` at the `/accounts` endpoint:

{% highlight ruby %}
# PUT /accounts/123

{
  data: {
    type: "accounts",
    id: "123",
    attributes: { name: "updated" }
    relationships: {
      people: {
        data: [
          { id: "1", type: "people", method: "update" }
        ]
      }
    }
  },
  included: [
    {
      type: "people",
      id: "1",
      attributes: { name: "updated" }
    }
  ]
}
{% endhighlight %}

Here we've update the `Account` and associated `Person` in a single
request. You'll see this is nothing more than a mirror of a
["sideloading" payload](http://jsonapi.org/format/#document-compound-documents), with one key addition - because HTTP verbs only apply to the top-level resource, we add a `method` key for all associated resources. Because we're sticking to the convention of pairing a Resource with a verb, we call this "REST with Relationships". Verbs can be one of `create`, `update`, `destroy` or `disassociate`.

> Read more about the [Sideposting Concept]({{site.github.url}}/concepts#sideposting)

There's not much code to satisfy this document. Make sure the
relationship is defined in your `Resource`:

{% highlight ruby %}
# app/resources/account_resource.rb

has_many :people,
  resource: PersonResource,
  foreign_key: :account_id,
  scope: -> { Person.all }
{% endhighlight %}

And whitelisted in your controller:

{% highlight ruby %}
# app/controllers/accounts_controller.rb

strong_resource :account do
  has_many :people
end
{% endhighlight %}

That's it!

#### temp-id

There's one final concept in sideposting, specific to `create`. We need
to tell our clients how to update an in-memory object with the
newly-minted `id` from the server. To do this, we pass `temp-id` (a random uuid) in the
request instead of `id`:

{% highlight ruby %}
# create an Account with a Person in a single request
{
  data: {
    type "accounts",
    attributes: { name: "new account" },
    relationships: {
    people: {
      data: [
        { :'temp-id' => "abc123", type: "people" }
      ]
    }
  },
  included: [
    {
      type: "people",
      :"temp-id" => "abc123",
      attributes: { name: "John Doe" }
    }
  ]
}
{% endhighlight %}

Clients like [JSORM]({{site.github.url}}/js/home) will handle this for you
automatically.
