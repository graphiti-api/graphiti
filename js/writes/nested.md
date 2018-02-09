---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Nested Writes

You can write a `Model` and all of its relationships in a single
request. Keep in mind normal dirty tracking rules still apply - nothing
is sent to the server unless it is dirty.

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let author = new Author()
  let comment = new Comment({ author })
  let post = new Post({ comments: [comment] })

  // post.save({ with: "comments" })
  // post.save({ with: ["comments", "blog"] })
  post.save({ with: { comments: 'author' }})
  {% endhighlight %}

  {% highlight javascript %}
  var author = new Author();
  var comment = new Comment({ author: author });
  var post = new Post({ comments: [comment] });

  // post.save({ with: "comments" })
  // post.save({ with: ["comments", "blog"] })
  post.save({ with: { comments: "author" }});
  {% endhighlight %}
</div>

Use `model.isMarkedForDestruction = true` to delete the associated
object. Use `model.isMarkedForDisassociation = true` to remove the association
without deleting the underlying object:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let post = (await Post.includes("comments").first()).data
  post.comments[0].isMarkedForDestruction = true
  post.comments[1].isMarkedForDisassociation = true

  // destroys the first comment
  // disassociates the second comment
  await post.save({ with: "comments" })
  {% endhighlight %}

  {% highlight javascript %}
  Post.includes("comments").first().then(function(response) {
    var post = response.data;
    post.comments[0].isMarkedForDestruction = true;
    post.comments[1].isMarkedForDisassociation = true;

    // destroys the first comment
    // disassociates the second comment
    post.save({ with: "comments" })
  });
  {% endhighlight %}
</div>

You may want to send *only* the `id` of the related object to the server - ensuring the models are associated without updating attributes by
accident. Just add `.id` to the relationship name:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  post.save({ with: "comments.id" })
  {% endhighlight %}

  {% highlight javascript %}
  post.save({ with: "comments.id" })
  {% endhighlight %}
</div>


<div class="clearfix">
  <h2 id="next">
    <a href="/js/middleware">
      NEXT:
      <small>Middleware</small>
      &raquo;
    </a>
  </h2>
</div>

{% include highlight.html %}

