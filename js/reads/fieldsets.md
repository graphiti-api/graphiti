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
  <p>/posts?fields[posts]=title,status</p>
</blockquote>

When dealing with relationships, it may be easier to pass an object,
where the key is the corresponding JSONAPI type. This will be exactly
what's sent to the server in `?fields`:

{% highlight typescript %}
Post.select({
  posts: ['title', 'status'],
  comments: ['created_at']
}).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?fields[posts]=title,status&fields[comments]=created_at</p>
</blockquote>


### Extra Fieldsets

Use `#selectExtra()` to explicitly request a field that doesn't usually
come back (often computationally expensive):

{% highlight typescript %}
Post.selectExtra(['highlights', 'cumulative_ranking']).all()
{% endhighlight %}
<blockquote class="url">
  <p>/posts?extra_fields[posts]=highlights,cumulative_ranking</p>
</blockquote>

Just like the `select` example above, feel free to pass an object
specifying the fields for each relationship.

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/reads/statistics">
      NEXT:
      <small>Statistics</small>
      &raquo;
    </a>
  </h2>
</div>
