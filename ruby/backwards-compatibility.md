---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Backwards Compatibility

Before we deploy our code to production, we want to ensure we
aren't introducing any backwards incompatibilities that will break
existing clients. Of course, tests are our first line of defense here.
But a developer could always simply update the test and introduce a
backwards-incompatibility. This is why JSONAPI Suite comes with an
additional backwards-compatibility check you can run in your Continuous
Integration pipeline.

In the course of writing our application, we [autodocumented
with Swagger]({{site.github.url}}/ruby/swagger). That means our
`swagger.json` is effectively a **schema** - a definition of
attributes, types, query parameters and payloads. We can compare the
`swagger.json` of a given commit to what's running in production to
see if any backwards-incompatibilities were introduced.

If you used our [generator]({{site.github.url}}/ruby/installation) to set up your application, you'll have noticed this line added to `Rakefile`:

{% highlight ruby %}
require 'jsonapi_swagger_helpers'
{% endhighlight %}

This allows us to run the rake task

{% highlight bash %}
rake swagger_diff['my_api','http://example.com']
{% endhighlight %}

This task will:

  * Pull down the schema from `http://example.com/my_api/swagger.json`.
  * Compare it to the `swagger.json` generated locally.

This uses [swagger-diff](https://github.com/civisanalytics/swagger-diff) underneath the hood. You'll get helpful output noting any missing filters, incorrect types, or other backwards incompatibilities.
