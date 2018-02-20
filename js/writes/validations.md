---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Validations

JSONAPI Suite is already set up to return validation errors with a
`422` response code and JSONAPI-compliant [errors payload](http://jsonapi.org/format/#errors). Those errors will be automatically assigned, and removed on subsequent requests:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let success = await post.save()
  console.log(success) // false
  post.errors.title // { message: "Can't be blank", ... }
  post.title = "no longer blank"
  success = await post.save()
  console.log(success) // true
  post.errors // {}
  {% endhighlight %}

  {% highlight javascript %}
  post.save().then(function(success) {
    console.log(success) // false
    post.errors.title // { message: "Can't be blank", ... }
    post.title = "no longer blank"
    post.save().then(function(success) {
      console.log(success); // true
      post.errors // {}
    });
  })
  {% endhighlight %}
</div>

<div class="clearfix">
  <h2 id="next">
    <a href="/js/writes/dirty-tracking">
      NEXT:
      <small>Dirty Tracking</small>
      &raquo;
    </a>
  </h2>
</div>

{% include highlight.html %}
