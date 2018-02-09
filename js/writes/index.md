---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Writes

Similar to `ActiveRecord`, you can simply call `#save()` on a model
instance. JSORM will [create](http://jsonapi.org/format/#crud-creating) (`POST`) or [update](http://jsonapi.org/format/#crud-updating) (`PATCH`) as needed.

`#save()` returns a `Promise` that will resolve a `boolean` - `true`
when the server returns a 200-ish response code, `false` when the server
returns a `422` response code (see
[validations](/js/writes/validations)). As always, anything else will
reject the promise.

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let blog = new Blog({ title: "My Blog" })
  let success = await blog.save() // POST /blogs
  console.log(success) // true/false

  blog.title = "Updated Title"
  success = await blog.save() // PUT /blogs/:id
  console.log(success) // true/false
  {% endhighlight %}

  {% highlight javascript %}
  var blog = new Blog({ title: "My Blog" });
  // POST /blogs
  blog.save().then(function(success) {
    console.log(success); // true/false

    blog.title = "Updated Title":
    // PUT /blogs/:id
    blog.save().then(function(success) {
      console.log(success) // true/false
    });
  });
  {% endhighlight %}
</div>

After saving, the instance will automatically pick up any
server-assigned attributes:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let post = new Post()
  await post.save()
  post.id // server-assigned value
  post.createdAt // server-assigned value
  {% endhighlight %}

  {% highlight javascript %}
  var post = new Post();
  post.save().then(function(success) {
    post.id // server-assigned value
    post.createdAt // server-assigned value
  });
  {% endhighlight %}
</div>

If a `Model` was instantiated with data from the server, `isPersisted`
will return `true`. This means that we can assign IDs on the client
without any adverse behavior; we can also manually mark objects as
persisted for testing purposes:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let blog = new Blog({ id: 123 })
  blog.isPersisted // false
  await blog.save() // POST /blogs
  blog.isPersisted // true
  blog.id // 123

  // Manually mark an instance as persisted
  blog = new Blog({ id: 123 })
  blog.isPersisted = true
  await blog.save() // PUT /blogs/123
  {% endhighlight %}

  {% highlight javascript %}
  var blog = new Blog({ id: 123 });
  blog.isPersisted // false
  // POST /blogs
  blog.save().then(function(response) {
    blog.isPersisted // true
    blog.id // 123
  });

  // Manually mark an instance as persisted
  var blog = new Blog({ id: 123 });
  blog.isPersisted = true
  blog.save() // PUT /blogs/123
  {% endhighlight %}
</div>

Notably, **only dirty (changed) attributes will be sent to the server**. This prevents race conditions and unexpected side-effects. In the following example, `Post` has attributes `title`, `description`, and `createdAt`:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let post = (await Post.first())
  post.title = "updated"
  // ONLY title sent to the server
  await post.save()
  // Title is now synced with the server
  post.description = "updated"
  // ONLY description sent to the server
  await post.save()
  {% endhighlight %}

  {% highlight javascript %}
  Post.first().then(function(response) {
    var post = response.data;
    post.title = "updated";
    // ONLY title sent to the server
    post.save().then(function(response) {
      // Title is now synced with the server
      post.description = "updated";
      // ONLY description sent to the server
      post.save();
    });
  });
  {% endhighlight %}
</div>

<div class="clearfix">
  <h2 id="next">
    <a href="/js/writes/validations">
      NEXT:
      <small>Validations</small>
      &raquo;
    </a>
  </h2>
</div>

{% include highlight.html %}
