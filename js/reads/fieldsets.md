---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Sparse Fieldsets

Use `#select()` to limit the fields returned by the server:

{% highlight typescript %}
Post.select(['title', 'status']).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?fields=title,status</p>
</blockquote>

### Extra Fieldsets

Use `#selectExtra()` to explicitly request a field that doesn't usually
come back (often computationally expensive):

{% highlight typescript %}
Post.selectExtra(['highlights', 'cumulative_ranking']).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?extra_fields=highlights,cumulative_ranking</p>
</blockquote>

<div class="clearfix">
  <h2 id="next">
    <a href="/js/reads/statistics">
      NEXT:
      <small>Statistics</small>
      &raquo;
    </a>
  </h2>
</div>

{% include highlight.html %}
