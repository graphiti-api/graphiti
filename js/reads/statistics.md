---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Statistics

Use `#stats()` to request statistics. Access stats within `meta`:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
let { data } = await Post.stats({ total: "count" }).all()
data.meta.stats.total.count // the total count
{% endhighlight %}

{% highlight javascript %}
Post.stats({ total: "count" }).all().then(function(response) {
  response.meta.stats.total.count // the total count
})
{% endhighlight %}
</div>
<blockquote class="url">
  <p>/posts?stats[total]=count</p>
</blockquote>

Stats are always independent of pagination. If you request the total count, you'll get the total count even if you're limiting to 10 per page. This means to get **only** statistics - avoid returning `Post` instances altogether - simply request `0` results per page:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
let { data } = await Post.per(0)stats({ total: "count" }).all()
data.meta.stats.total.count // the total count
{% endhighlight %}

{% highlight javascript %}
Post
  .per(0)
  .stats({ total: "count" })
  .all().then(function(response) {
    response.meta.stats.total.count // the total count
  })
{% endhighlight %}
</div>
<blockquote class="url">
  <p>/posts?stats[total]=count&page[size]=0</p>
</blockquote>

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/writes">
      NEXT:
      <small>Writes</small>
      &raquo;
    </a>
  </h2>
</div>

{% include highlight.html %}
