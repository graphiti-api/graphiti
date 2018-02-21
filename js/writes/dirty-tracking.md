---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Dirty Tracking

When an attribute has been modified, but has not yet been saved to the
server, it is considered "dirty". Use `#isDirty()` to see if any attribute is dirty, use the `#changes()` method to see all dirty attributes.

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let post = await Post.first()
  post.title // "original"
  post.isDirty() // false
  post.changes() // {}

  post.title = "changed"
  post.isDirty() // true
  post.changes() // { title: ["original", "changed"] }

  await post.save()
  post.isDirty() // false
  post.changes() // {}
  {% endhighlight %}

  {% highlight javascript %}
  Post.first().then(function(response) {
    var post = response.data;

    post.title; // "original"
    post.isDirty(); // false
    post.changes(); // {}

    post.title = "changed";
    post.isDirty(); // true
    post.changes(); // { title: ["original", "changed"] }

    post.save().then(function(success) { // true
      post.isDirty(); // false
      post.changes(); // {}
    });
  });
  {% endhighlight %}
</div>

> Remember, only dirty attributes are sent to the server when `#save()`
> is called.

`#isDirty()` *can* take into account relationships - just pass a
string, array, or object or relationship names. A relationship is
considered dirty if:

* Any objects in the relationship have dirty attributes
* An object was removed from a `hasMany` relationship
* An object was added to a `hasMany` relationship
* Any object within the relationship was replaced with a different
object.

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let post = await Post.first()
  post.comments[0].text = "my comment"
  post.isDirty("comments") // true

  post = await Post.first()
  post.comments.push(new Comment())
  post.isDirty("comments") // true

  post = await Post.first()
  post.comments.splice(1, 1)
  post.isDirty("comments") // true

  post = await Post.first()
  post.blog // an existing Blog instance
  post.blog = (await Blog.first()).data
  post.isDirty("blog") // true

  // check nested relationships
  post.isDirty(["blog", { comments: "author" }])
  {% endhighlight %}

  {% highlight javascript %}
  Post.first().then(function(response) {
    var post = response.data;
    post.comments[0].text = "my comment";
    post.isDirty("comments"); // true
  });

  Post.first().then(function(response) {
    var post = response.data;
    post.comments.push(new Comment());
    post.isDirty("comments"); // true
  });

  Post.first().then(function(response) {
    var post = response.data;
    post.comments.splice(1, 1);
    post.isDirty("comments"); // true
  });

  Post.first().then(function(response) {
    var post = response.data;
    post.blog; // an existing Blog instance

    Blog.first().then(function(blog) {
      post.blog = (await Blog.first()).data
      post.isDirty("blog") // true
    });
  });

  // check nested relationships
  post.isDirty(["blog", { comments: "author" }])
  {% endhighlight %}
</div>

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/writes/nested">
      NEXT:
      <small>Nested Writes</small>
      &raquo;
    </a>
  </h2>
</div>
