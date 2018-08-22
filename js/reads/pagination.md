---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Pagination

Use `#per()` to set the limit per page:

{% highlight typescript %}
Post.per(10).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?page[size]=10</p>
</blockquote>

Use `#page()` to set the current page:

{% highlight typescript %}
Post.page(5).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?page[number]=5</p>
</blockquote>

When chained together (10 per page, the 5th page):

{% highlight typescript %}
Post.page(5).per(10).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?page[size]=10&page[number]=5</p>
</blockquote>

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/reads/filtering">
      NEXT:
      <small>Filtering</small>
      &raquo;
    </a>
  </h2>
</div>
