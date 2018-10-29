---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Includes

Use `#includes()` to ["sideload"](http://jsonapi.org/format/#fetching-includes) associations:

{% highlight typescript %}
Post.includes("comments").all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?include=comments</p>
</blockquote>

You can also pass an array of associations:

{% highlight typescript %}
Post.includes(["blog", "comments"]).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?include=blog,comments</p>
</blockquote>

Or an object for nested associations:

{% highlight typescript %}
Post.includes(["blog", { comments: "author" }]).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?include=blog,comments.author</p>
</blockquote>

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/reads/nested-queries">
      NEXT:
      <small>Nested Queries</small>
      &raquo;
    </a>
  </h2>
</div>
