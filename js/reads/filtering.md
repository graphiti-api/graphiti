---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Filtering

Use `#where()` to apply filters:

{% highlight typescript %}
Post.where({ important: true }).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?filter[important]=true</p>
</blockquote>

`#where()` clauses can be chained together. If the same key is seen
twice, it will be overridden:

{% highlight typescript %}
Post
  .where({ important: true })
  .where({ ranking: 10 })
  .where({ important: false })
  .all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?filter[important]=false&filter[ranking]=10</p>
</blockquote>

`#where()` clauses are based on **server implementation**. The key
should be exactly as the server understands it. Here are some common
conventions we promote:

{% highlight typescript %}
// id greater than 5
Post.where({ id_gt: 5 }).all()

// id greater than or equal to 5
Post.where({ id_gte: 5 }).all()

// id less than 5
Post.where({ id_lt: 5 }).all()

// id less or equal to 5
Post.where({ id_lte: 5 }).all()

// title starts with "foo"
Post.where({ title_prefix: "foo" }).all()

// OR these two values
Post.where({ status_or: ['draft', 'review'] })

// AND these two values (default)
Post.where({ status: ['draft', 'review'] })
{% endhighlight %}

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/reads/fieldsets">
      NEXT:
      <small>Fieldsets</small>
      &raquo;
    </a>
  </h2>
</div>
