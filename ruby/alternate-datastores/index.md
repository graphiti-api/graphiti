---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Alternate Datastores

It's important to note that `ActiveRecord` is nothing but a sensible
default. Because you have [full control over the
query]({{site.github.url}}/ruby/reads/resources) JSONAPI Suite can be
used with any datastore, from MongoDB to HTTP service calls.

In this section, we'll show examples customizing resource logic, then
packaging that logic into reusable `Adapter`s.

> Keep in mind, multiple datastores can be blended in a single request.
> We can load `Post`s from a SQL database, and "sideload" `Comment`s
> from MongoDB seamlessly.

* [ElasticSearch
  Example]({{site.github.url}}/ruby/alternate-datastores/elasticsearch)

* [PORO Example]({{site.github.url}}/ruby/alternate-datastores/poro)

* [HTTP Service
  Example]({{site.github.url}}/ruby/alternate-datastores/http)

* [Adapters]({{site.github.url}}/ruby/alternate-datastores/adapters)
