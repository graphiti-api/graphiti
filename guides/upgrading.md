---
layout: page
---

Upgrading from JSONAPI Suite
============================

The early version of Graphiti was JSONAPI Suite. If you are a JSONAPI
Suite user, here's how to upgrade your existing API.

The work here is mostly consolidating logic that currently lives in
multiple files into a single Resource, and rewriting specs. The good
news is that, because we emphasize full-stack integration tests, we can
perform the upgrade with confidence by ensuring our tests pass.

### Before You Start

Begin by understanding Graphiti. Walk through the documentation and
[sample application](https://github.com/graphiti-api/employee_directory) to get a feel for the new API. [Here's a controller](https://github.com/graphiti-api/employee_directory/blob/master/app/controllers/employees_controller.rb).

There is no Swagger UI equivalent for Graphiti. Swagger is a
poor fit for graph APIs, and we instead rely on a custom Graphiti
Schema. Instead, check out [Vandal]({{site.github.url}}/guides/vandal).

### Setup

Start by removing the gems `jsonapi_suite`, `jsonapi-rails`,
`jsonapi_swagger_helpers`, and `swagger-diff`. You'll eventually remove
`jsonapi_spec_helpers`, but keep it for now.

Add gems `graphiti`, `graphiti_spec_helpers` and `responders`. See the
[Sample App Gemfile](https://github.com/graphiti-api/employee_directory/blob/master/Gemfile).

Move `spec/api` to `spec/legacy`.

Remove `config/initializers/strong_resources.rb`,
`config/initializers/jsonapi.rb`, `app/controllers/docs_controller.rb`,
and the Swagger UI that lives under `public`.

Remove swagger helpers from `Rakefile`.

Grep for `JsonapiErrorable` and change to `GraphitiErrors`.

Make `spec/rails_helper.rb` correct (though keep `jsonapi_spec_helpers`
for now). [See sample](https://github.com/graphiti-api/employee_directory/blob/master/spec/rails_helper.rb).

At this point, running your specs should give you a lot of errors like
`"index" not found`.

### Upgrading

Upgrade your [ApplicationController](https://github.com/graphiti-api/employee_directory/blob/master/app/controllers/application_controller.rb).

Upgrade your [ApplicationResource](https://github.com/graphiti-api/employee_directory/blob/master/app/resources/application_resource.rb).

  * Note that this references `Rails.application.routes.default_url_options[:host]`. That's set in [config/application.rb](https://github.com/graphiti-api/employee_directory/blob/master/config/application.rb#L22).
  * Note the `endpoint_namespace`. Make this match your current routes.
  * Reference `ApplicationResource.endpoint_namespace` [in your routes file](https://github.com/graphiti-api/employee_directory/blob/master/config/routes.rb#L2).

Begin rewriting your Resources. Go through `spec/payloads` and add these
attributes/types to the Resource. Remember to mark these as `only:
[:readable]`, or `writable: false`, etc. Look at
`config/initializers/strong_resources.rb` to see if an attribute should
be writable.

Rewrite custom `allow_filters`. If it's a one-liner, just make sure
there is a corresponding attribute. If there is custom logic:

{% highlight ruby %}
allow_filter :foo do |scope, value|
  # ... code ...
end

# BECOMES

filter :foo, :string, only: [:eq], single: true do
  eq do |scope, value|
    # ... code ...
  end
end
{% endhighlight %}

Two things about filters: by default, `value` is now always array. Pass
`single: true` if your logic only supports a single value. Also: a
filter with a given type now comes with operators - `string` gets
`prefix`, `suffix`, etc. If you don't support these, limit operations
with `only:`.

Note that we now support multiple content types for read requests:
`.json` and `.xml`. If you have any clients explicitly putting `.json`
at the end of the URL, they are now going to get a simple JSON response
instead of JSONAPI. Avoid the responders gem if you don't want this.

You may want to move some persistence logic to [before_commit]({{site.github.url}}/guides/concepts/resources#side-effects).

Resources now have [#base_scope]({{site.github.url}}/guides/concepts/resources#basescope). If you previously were using `default_filter` or passing in a custom scope in your controller, consider moving to `base_scope`:

{% highlight ruby %}
# app/resources/post_resource.rb
def base_scope
  Post.active
end
{% endhighlight %}

If you have manual sideloading logic with scope, it is **highly
recommended** you rewriting using `params` - see [relationship docs]({{site.github.url}}/guides/concepts/resources#relationships). If you **do** still need `scope`, it now yields the parent ids as the first argument and the actual parent models as the second.

At this point, get all your `spec/legacy` specs passing.

When you're done, generate the new [Resource and API Specs]({{site.github.url}}/guides/concepts/testing). Note that much of this is syntax changes, you can copy/paste large amounts of logic from `spec/legacy`. To ease this process, try `rails g graphiti:api_test PostResource` and `rails g graphiti:resource_test PostResource`.

You should now have the upgraded **and** legacy test suite working. We
can now remove the legacy specs:

  * Remove `jsonapi_spec_helpers` gem
  * `rm -rf spec/payloads`
  * `rm -rf spec/legacy`

And you're done! Deploy to a staging environment and verify your API
supports all your real-world scenarios.

### Persistence

Though you can get specs passing with your existing `create`, `update`,
etc, try to rewrite them using hooks. It's no longer considered a best
practice to override these methods because you'll be bypassing hooks.
Instead, add hooks and override `def save(model)` if you need to.

### Gotchas

We use `respond_with` in read operations and `render jsonapi:` in write
operations. This is because the `responders` gem bypasses renderers for
`PUT`, and a few other minor issues.

<br />
<br />
