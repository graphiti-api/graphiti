---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Strong Resources

> View the Sample App: [Basic](https://github.com/jsonapi-suite/employee_directory/compare/step_15_validations...step_16_strong_resources) &nbsp;\|&nbsp;[Nested](https://github.com/jsonapi-suite/employee_directory/compare/step_19_custom_persistence...step_20_association_create)

> [View the Strong Resources Github Documentation](https://jsonapi-suite.github.io/strong_resources)

Rails 4 introduced the concept of [Strong Parameters](http://edgeguides.rubyonrails.org/action_controller_overview.html#strong-parameters), a way to whitelist incoming parameters for a given write operation. The folks at Zendesk took it a step further with [Stronger Parameters](https://github.com/zendesk/stronger_parameters), which added type-checking to the strong parameter checks.

This works well for traditional REST endpoints that can put the logic in
the controller. But JSONAPI Suite endpoints can "sidepost" objects at
multiple endpoints - we might save a `Person` at the `/people` endpoint,
but also sidepost from the `/accounts` endpoint. The strong parameters
logic would need to be duplicated across controllers.

Enter [Strong Resources](https://jsonapi-suite.github.io/strong_resources). Define whitelist templates in one place, and re-use them across your application:

{% highlight ruby %}
# config/initializers/strong_resources.rb
StrongResources.configure do
  strong_resource :account do
    attribute :name, :string
    attribute :active, :boolean
  end
end
{% endhighlight %}

{% highlight ruby %}
# app/controllers/accounts_controller.rb

before_action :apply_strong_params, only: [:create, :update]

strong_resource :account
{% endhighlight %}

Now, whenever we `POST` or `PUT` to `/accounts`, the request
`attributes` must come in this format. If an extra attribute is given -
perhaps a read-only `rate_limit` attribute - the request will be
rejected. If `active` comes in as a string instead of a boolean, the
request will be rejected.

Let's sidepost a `Person` record to the `/accounts` endpoint:

{% highlight ruby %}
# config/initializers/strong_resources.rb

# ... code ...
strong_resource :person do
  attribute :name, :string
  attribute :age, :integer
end
{% endhighlight %}

{% highlight ruby %}
# app/controllers/accounts_controller.rb

strong_resource :account do
  has_many :people
end
{% endhighlight %}

We can now sidepost `Person` records - via the `people` relationship -
to the `/accounts` endpoint. If the `Person` attributes don't match the
`:person` strong resource template, the request will be rejected.

By default, we only allow `create` and `update` of associations, but you
can opt-in to `destroy` and `disassociate` as well:

{% highlight ruby %}
# app/controllers/accounts_controller.rb

strong_resource :account do
  has_many :people, destroy: true, disassociate: true
end
{% endhighlight %}

There are a variety of ways to customize strong resource templates -
like allowing certain parameters only on `update` but not `create`. Head
over to the [strong_resources documentation](https://jsonapi-suite.github.io/strong_resources/) for a more in-depth
overview.

<blockquote>
  Note: a common issue is allowing an input to be `null`. You can define your own types, or
  {% highlight ruby %}
# config/initializers/strong_resources.rb
ActionController::Parameters.allow_nil_for_everything = true
  {% endhighlight %}
</blockquote>
