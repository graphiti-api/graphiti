---
title: 'Reads'
sidebar_position: 4
---

The interface for read operations is a simpler version of the [ActiveRecord Query Interface](http://guides.rubyonrails.org/active_record_querying.html). Instead of generating SQL, we'll be generating JSONAPI requests.

## Basic Finders

Execute queries with `.all()`, `find()`, or `.first()`:

```typescript
let response = await Post.all()
response.data // array of Post instances
```
```javascript
Post.all().then(function(response) {
  response.data // array of Post instances
});
```
<blockquote class="url">
  <p>GET /posts</p>
</blockquote>

```typescript
let response = await Post.find(123)
response.data // Post instance
```
```javascript
Post.find(123).then(function(response) {
  response.data // Post instance
});
```
<blockquote class="url">
  <p>GET /posts/123</p>
</blockquote>

```typescript
let response = await Post.first()
response.data // Post instance
```
```javascript
Post.first().then(function(response) {
  response.data // Post instance
});
```
<blockquote class="url">
  <p>GET /posts?page[size]=1</p>
</blockquote>

## Composable Queries with Scopes

The beauty of ORMs is their ability to compose queries. We'll be doing this by chaining together `Scope`s (query fragments). All of the methods you see on this page can be chained together - the request will not fire until the chain ends with `all()`, `first()`, or `find`. Example:

```typescript
let scope = Post.order({ name: "desc" })

if (someCheckboxIsChecked) {
  scope = scope.where({ important: true })
} else {
  scope = scope.where({ important: false })
}

scope.all() // request fires
```

```javascript
var scope = Post.order({ name: "desc" });

if (someCheckboxIsChecked) {
  scope = scope.where({ important: true });
} else {
  scope = scope.where({ important: false });
}

scope.all() // request fires
```
<blockquote class="url">
  <p>/posts?sort=-name&filter[important]=true</p>
  <p>/posts?sort=-name&filter[important]=false</p>
</blockquote>

In practice, you'll probably have some scopes you want to re-use across different contexts. A best practice is to store these scopes as class methods (static methods) in the model:

```typescript
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
```

```javascript
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
```
<blockquote class="url">
<p>/posts?sort=-ranking&stats[total]=count&page[size]=10&filter[ranking_gt]=8</p>
</blockquote>

## Metadata

The [meta information](http://jsonapi.org/format/#document-meta) of the JSONAPI response is available as a POJO on the response:

```typescript
let response = await Post.all()
response.meta // { stats: { total: { count: 100 } } }
```
```javascript
await Post.all().then(function(response) {
  response.meta // { stats: { total: { count: 100 } } }
})
```

## Promises and Async/Await

The result of `all()`, `first()` or `find` is a [Promise](https://developers.google.com/web/fundamentals/primers/promises). The promise will resolve to a `Response` object.

A `Response` object has three keys - `data`, `meta`, and `raw`. `data` - the one you'll be using the most - will be a `Model` instance (or array of `Model`) instances. `meta` will be the [Meta Information](http://jsonapi.org/format/#document-meta) returned by the API (mostly used for statistics in our case). `raw` is only used to introspect the raw response document.

```typescript
Post.all().then((response) => {
  response.data // array of Post instances
  response.meta // js object from the server
  response.raw // js response document
})
```

```javascript
Post.all().then(function(response) {
  response.data // array of Post instances
  response.meta // js object from the server
  response.raw // js response document
});
```
<blockquote class="url">
  <p>/posts</p>
</blockquote>

Hopefully you're running in an environment that supports ES7's [Async/Await](https://hackernoon.com/6-reasons-why-javascripts-async-await-blows-promises-away-tutorial-c7ec10518dd9). This makes things even easier:

```typescript
let { data } = await Post.all()
data // array of Post instances

// alternatively

let posts = (await Post.all()).data
posts // array of Post instances
```
<blockquote class="url">
  <p>/posts</p>
</blockquote>

## Filtering

Use `#where()` to apply filters:

```typescript
Post.where({ important: true }).all()
```
<blockquote class="url">
  <p>/posts?filter[important]=true</p>
</blockquote>

`#where()` clauses can be chained together. If the same key is seen twice, it will be overridden:

```typescript
Post
  .where({ important: true })
  .where({ ranking: 10 })
  .where({ important: false })
  .all()
```
<blockquote class="url">
  <p>/posts?filter[important]=false&filter[ranking]=10</p>
</blockquote>

`#where()` clauses are based on **server implementation**. The key should be exactly as the server understands it. Here are some common conventions we promote:

```typescript
// id greater than 5
Post.where({ id_gt: 5 }).all()

// id greater than or equal to 5
Post.where({ id_gte: 5 }).all()

// id less than 5
Post.where({ id_lt: 5 }).all()

// id less or equal to 5
Post.where({ id_lte: 5 }).all()

// title starts with "foo"
Post.where({ title: { prefix: "foo" } }).all()

// OR these two values
Post.where({ status_or: ['draft', 'review'] })

// AND these two values (default)
Post.where({ status: ['draft', 'review'] })
```

### Escaping Values

[Graphiti treats a comma as a delimiter of multiple values](/concepts/resources#escaping-values). To escape the comma and tell Graphiti this is a single value, wrap it in `{{curlies}}`:

```typescript
Post.where({ title: "{{Hello World, here I am}}" })
```

## Sorting

Use `#order()` to sort.

If passed a string, it will default to **ascending**:

```typescript
Post.order("title").all()
```
<blockquote class="url">
  <p>/posts?sort=title</p>
</blockquote>


Otherwise, pass an object:

```typescript
Post.order({ title: "desc" }).all()
```
<blockquote class="url">
  <p>/posts?sort=-title</p>
</blockquote>

For multisort, chain multiple `#order()` clauses:

```typescript
Post
  .order({ title: "desc" })
  .order("ranking")
  .all()
```
<blockquote class="url">
  <p>/posts?sort=-title,ranking</p>
</blockquote>

## Pagination

Use `#per()` to set the limit per page:

```typescript
Post.per(10).all()
```
<blockquote class="url">
  <p>/posts?page[size]=10</p>
</blockquote>

Use `#page()` to set the current page:

```typescript
Post.page(5).all()
```
<blockquote class="url">
  <p>/posts?page[number]=5</p>
</blockquote>

When chained together (10 per page, the 5th page):

```typescript
Post.page(5).per(10).all()
```
<blockquote class="url">
  <p>/posts?page[size]=10&page[number]=5</p>
</blockquote>

## Fieldsets

### Sparse Fieldsets

Use `#select()` to limit the fields returned by the server:

```typescript
Post.select(['title', 'status']).all()
```
<blockquote class="url">
  <p>/posts?fields[posts]=title,status</p>
</blockquote>

When dealing with relationships, it may be easier to pass an object, where the key is the corresponding JSONAPI type. This will be exactly what's sent to the server in `?fields`:

```typescript
Post.select({
  posts: ['title', 'status'],
  comments: ['created_at']
}).all()
```
<blockquote class="url">
  <p>/posts?fields[posts]=title,status&fields[comments]=created_at</p>
</blockquote>

### Extra Fieldsets

Use `#selectExtra()` to explicitly request a field that doesn't usually come back (often computationally expensive):

```typescript
Post.selectExtra(['highlights', 'cumulative_ranking']).all()
```
<blockquote class="url">
  <p>/posts?extra_fields[posts]=highlights,cumulative_ranking</p>
</blockquote>

Just like the `select` example above, feel free to pass an object specifying the fields for each relationship.

## Includes

Use `#includes()` to ["sideload"](http://jsonapi.org/format/#fetching-includes) associations:

```typescript
Post.includes("comments").all()
```
<blockquote class="url">
  <p>/posts?include=comments</p>
</blockquote>

You can also pass an array of associations:

```typescript
Post.includes(["blog", "comments"]).all()
```
<blockquote class="url">
  <p>/posts?include=blog,comments</p>
</blockquote>

Or an object for nested associations:

```typescript
Post.includes(["blog", { comments: "author" }]).all()
```
<blockquote class="url">
  <p>/posts?include=blog,comments.author</p>
</blockquote>

## Nested Queries

We can nest all read operations at any level of the graph. Let's say we wanted to fetch all `Post`s and their `Comment`s...but only return comments that are `active`, sorted by `created_at` descending. We can create a `Comment` scope as normal, then `#merge()` it into our `Post` scope:

```typescript
let commentScope = Comment
  .where({ active: true })
  .order({ created_at: "desc" })
Post
  .includes("comments")
  .merge({ comments: commentScope })
  .all()
```

```javascript
var commentScope = Comment
  .where({ active: true })
  .order({ created_at: "desc" })
Post
  .includes("comments")
  .merge({ comments: commentScope })
  .all()
```
<blockquote class="url">
  <p>/posts?include=comments&filter[comments][active]=true&sort=-comments.active</p>
</blockquote>

Because this can get verbose, it's often desirable to store it on the class:

```typescript
class Comment extends ApplicationRecord {
  // ... code ...
  static recent() {
    return this
      .where({ active: true })
      .order({ created_at: "desc" })
  }
}

Post.merge({ comments: Comment.recent() }).all()
```

```javascript
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

Post
  .includes("comments")
  .merge({ comments: Comment.recent() })
  .all()
```

Any number of scopes can be merged in. Just remember to `#include()` and `#merge()` relationship names **as the server understands them**:

```typescript
class Dog extends ApplicationRecord {
  @BelongsTo() person: Person
}

// We've modeled this as Dog > person in javascript
// And Person is jsonapiType "people"
// But the server defined the relationship as "owner"
Dog.includes("owner").merge({ owner: Person.limitedFields() })
```

```javascript
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
```

## Statistics

Use `#stats()` to request statistics. Access stats within `meta`:

```typescript
let { data } = await Post.stats({ total: "count" }).all()
data.meta.stats.total.count // the total count
```

```javascript
Post.stats({ total: "count" }).all().then(function(response) {
  response.meta.stats.total.count // the total count
})
```
<blockquote class="url">
  <p>/posts?stats[total]=count</p>
</blockquote>

Stats are always independent of pagination. If you request the total count, you'll get the total count even if you're limiting to 10 per page. This means to get **only** statistics - avoid returning `Post` instances altogether - request `0` results per page:

```typescript
let { data } = await Post.per(0)stats({ total: "count" }).all()
data.meta.stats.total.count // the total count
```

```javascript
Post
  .per(0)
  .stats({ total: "count" })
  .all().then(function(response) {
    response.meta.stats.total.count // the total count
  })
```
<blockquote class="url">
  <p>/posts?stats[total]=count&page[size]=0</p>
</blockquote>

  <h2 id="next">
    <a href="/js/writes">
      NEXT:
      <small>Writes</small>
      &raquo;
    </a>
  </h2>
