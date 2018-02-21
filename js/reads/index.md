---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Reads

The interface for read operations is a simpler version of the
[ActiveRecord Query Interface](http://guides.rubyonrails.org/active_record_querying.html).
Instead of generating SQL, we'll be generating JSONAPI requests.

### Composable Queries with Scopes

The beauty of ORMs is their ability to compose queries. We'll be doing
this by chaining together `Scope`s (query fragments). All of the methods
you see on this page can be chained together - the request will not fire
until the chain ends with `all()`, `first()`, or `find`. Example:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
let scope = Post.order({ name: "desc" })

if (someCheckboxIsChecked) {
  scope = scope.where({ important: true })
} else {
  scope = scope.where({ important: false })
}

scope.all() // request fires
  {% endhighlight %}

  {% highlight javascript %}
var scope = Post.order({ name: "desc" });

if (someCheckboxIsChecked) {
  scope = scope.where({ important: true });
} else {
  scope = scope.where({ important: false });
}

scope.all() // request fires
  {% endhighlight %}
</div>
<blockquote class="url">
  <p>/posts?sort=-name&filter[important]=true</p>
  <p>/posts?sort=-name&filter[important]=false</p>
</blockquote>

In practice, you'll probably have some scopes you want to re-use across
different contexts. A best practice is to store these scopes as class
methods (static methods) in the model:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
class Post extends ApplicationRecord {
  // ... code ...
  static superImportant() {
    return this
      .where({ ranking_gt: 8 })
      .order({ ranking: 'desc' })
      .stats({ total 'count' })
  }
}

// get 10 super important posts
let scope = Post.superImportant().per(10)
scope.all() // fire query
  {% endhighlight %}

  {% highlight javascript %}
const Post = ApplicationRecord.extend({
  // ... code ...
  static: {
    superImportant() {
      return this
        .where({ ranking_gt: 8 })
        .order({ ranking: 'desc' })
        .stats({ total 'count' })
    }
  }
})

// get 10 super important posts
var scope = Post.superImportant().per(10);
scope.all() // fire query
  {% endhighlight %}
</div>
<blockquote class="url">
<p>/posts?sort=-ranking&stats[total]=count&page[size]=10&filter[ranking_gt]=8</p>
</blockquote>

### Promises and Async/Await

The result of `all()`, `first()` or `find` is a [Promise](https://developers.google.com/web/fundamentals/primers/promises). The promise will resolve to a `Response` object.

A `Response` object has three keys - `data`, `meta`, and `raw`. `data` - the one
you'll be using the most - will be a `Model` instance (or array of
`Model`) instances. `meta` will be the [Meta Information](http://jsonapi.org/format/#document-meta) returned by the API (mostly used for statistics in our case). `raw` is only used to introspect the raw response document.

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
Post.all().then((response) => {
  response.data // array of Post instances
  response.meta // js object from the server
  response.raw // js response document
})
  {% endhighlight %}

  {% highlight javascript %}
Post.all().then(function(response) {
  response.data // array of Post instances
  response.meta // js object from the server
  response.raw // js response document
});
  {% endhighlight %}
</div>
<blockquote class="url">
  <p>/posts</p>
</blockquote>

Hopefully you're running in an environment that supports
ES7's [Async/Await](https://hackernoon.com/6-reasons-why-javascripts-async-await-blows-promises-away-tutorial-c7ec10518dd9). This makes things even easier:

{% highlight typescript %}
let { data } = await Post.all()
data // array of Post instances

// alternatively

let posts = (await Post.all()).data
posts // array of Post instances
{% endhighlight %}
<blockquote class="url">
  <p>/posts</p>
</blockquote>

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/reads/sorting">
      NEXT:
      <small>Sorting</small>
      &raquo;
    </a>
  </h2>
</div>

{% include highlight.html %}
