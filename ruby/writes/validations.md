---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Validations

> [View the JSONAPI Errors Spec](http://jsonapi.org/format/#errors)

> View the Sample App: [Server](https://github.com/jsonapi-suite/employee_directory/compare/step_14_create...step_15_validations) &nbsp;\|&nbsp; [Client](https://github.com/jsonapi-suite/employee-directory-vue/compare/step_10_nested_create...step_11_validations)

> [View the JS Documentation]({{site.github.url}}/js/writes/validations)

Validation errors are handled automatically for any models adhering to
the [ActiveModel::Validations API](http://api.rubyonrails.org/classes/ActiveModel/Validations.html).

After we've run the persistence logic - but before we close the
transaction - we check `model.errors`. If errors are present anywhere in
the graph, we rollback the transaction and return a JSONAPI-compliant [Error response](http://jsonapi.org/format/#errors):

{% highlight ruby %}
[
  {
    code: "unprocessable_entity",
    detail: "Name can't be blank",
    meta: {
      attribute: "name",
      message: "can't be blank"
    },
    source: {
      pointer: "/data/attributes/name"
    },
    status: "422",
    title: "Validation Error"
  }
]
{% endhighlight %}

This is true for nested write operations as well. Let's say we were
saving an `Employee` and their `Position`s in a single request, but one
of the positions had a validation error on a missing `title`:

{% highlight ruby %}
[
  {
    code:  'unprocessable_entity',
    status: '422',
    title: 'Validation Error',
    detail: "Title can't be blank",
    source: { pointer: '/data/attributes/title' },
    meta: {
      relationship: {
        attribute: :title,
        message: "can't be blank",
        code: :blank,
        name: :positions,
        id: '123',
        type: 'positions'
      }
    }
  }
]
{% endhighlight %}

This is enough information for a client to apply errors to the relevant
objects. In JSORM's case, you'd see:

{% highlight typescript %}
let success = await employee.save({ with: "positions" })
console.log(employee.errors) // # {}
let position = employee.positions[0]
console.log(position.errors.title.message) // # "Can't be blank"
{% endhighlight %}
