---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Sorting

Use `#order()` to sort.

If passed a string, it will default to **ascending**:

{% highlight typescript %}
Post.order("title").all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?sort=title</p>
</blockquote>


Otherwise, pass an object:

{% highlight typescript %}
Post.order({ title: "desc" }).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?sort=-title</p>
</blockquote>

For multisort, simply chain multiple `#order()` clauses:

{% highlight typescript %}
Post
  .order({ title: "desc" })
  .order("ranking")
  .all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?sort=-title,ranking</p>
</blockquote>

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/reads/pagination">
      NEXT:
      <small>Pagination</small>
      &raquo;
    </a>
  </h2>
</div>

{% include highlight.html %}
