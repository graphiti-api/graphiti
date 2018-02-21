---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Why JSORM?

Contracts like JSONAPI and GraphQL treat the API like a database. When querying a
database, we have two options:

  * Type the low-level query language directly (in the database world,
    this would be hand-typing SQL). This is the direction of GraphQL and
    apollo-client.
  * Use an ORM (like Rails's `ActiveRecord`, Phoenix's `Ecto`, Django's
    `DjangoORM`, or Node's `Sequelize`).

While both options have pros and cons, we tend to think ORMs
have two overwhelming benefits: ***ease of use*** and ***composable queries***.
We'll explore both these concepts in other sections.

So, we want a javascript ORM for our JSONAPI "database". Because
`ActiveRecord` is arguably the most well-known ORM, we've tried to match
its interface to make this library accessible to new users. That said,
you'll find we've tried to favor *explicitness* over *implicitness* in
order to avoid common `ActiveRecord` pitfalls.

</div>

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/installation">
      NEXT:
      <small>Installation</small>
      &raquo;
    </a>
  </h2>
</div>
