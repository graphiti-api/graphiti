---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Nested Queries

We can nest all read operations at any level of the graph. Let's say we wanted to
fetch all `Post`s and their `Comment`s...but only return comments that
are `active`, sorted by `created_at` descending. We can create a
`Comment` scope as normal, then `#merge()` it into our `Post` scope:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
let commentScope = Comment
  .where({ active: true })
  .order({ created_at: "desc" })
Post.merge({ comments: commentScope }).all()
{% endhighlight %}

{% highlight javascript %}
var commentScope = Comment
  .where({ active: true })
  .order({ created_at: "desc" })
Post
  .includes('comments')
  .merge({ comments: commentScope })
  .all()
{% endhighlight %}
</div>
<blockquote class="url">
  <p>/posts?include=comments&filter[comments][active]=true&sort=-comments.active</p>
</blockquote>

Because this can get verbose, it's often desirable to store it on
the class:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
class Comment extends ApplicationRecord {
  // ... code ...
  static recent() {
    return this
      .where({ active: true })
      .order({ created_at: "desc" })
  }
}

Post.merge({ comments: Comment.recent() }).all()
{% endhighlight %}

{% highlight javascript %}
const Comment = ApplicationRecord.extend({
  // ... code ...
  static: {
    recent: function() {
      return this
        .where({ active: true })
        .order({ created_at: "desc" })
    }
  }
})

Post.merge({ comments: Comment.recent() }).all()
{% endhighlight %}
</div>

Any number of scopes can be merged in. Just remember to `#include()`
and `#merge()` relationship names **as the server understands them**:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
class Dog extends ApplicationRecord {
  @BelongsTo() person: Person
}

// We've modeled this as Dog > person in javascript
// And Person is jsonapiType "people"
// But the server defined the relationship as "owner"
Dog.includes("owner").merge({ owner: Person.limitedFields() })
{% endhighlight %}

{% highlight javascript %}
const Dog = ApplicationRecord.extend({
  // ... code ...
  methods: {
    person: belongsTo()
  }
})

// We've modeled this as Dog > person in javascript
// And Person is jsonapiType "people"
// But the server defined the relationship as "owner"
Dog.includes("owner").merge({ owner: Person.limitedFields() })
{% endhighlight %}
</div>

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/reads/nested-queries">
      NEXT:
      <small>Nested Queries</small>
      &raquo;
    </a>
  </h2>
</div>

{% include highlight.html %}

