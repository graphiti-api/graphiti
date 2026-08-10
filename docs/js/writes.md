---
title: 'Writes'
sidebar_position: 5
---

Similar to `ActiveRecord`, you can call `#save()` on a model instance. Spraypaint will [create](http://jsonapi.org/format/#crud-creating) (`POST`) or [update](http://jsonapi.org/format/#crud-updating) (`PATCH`) as needed.

`#save()` returns a `Promise` that will resolve a `boolean` - `true` when the server returns a 200-ish response code, `false` when the server returns a `422` response code (see [validations](/js/writes#validations)). As always, anything else will reject the promise.

```typescript
  let blog = new Blog({ title: "My Blog" })
  let success = await blog.save() // POST /blogs
  console.log(success) // true/false

  blog.title = "Updated Title"
  success = await blog.save() // PUT /blogs/:id
  console.log(success) // true/false
```

```javascript
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
```

After saving, the instance will automatically pick up any server-assigned attributes:

```typescript
  let post = new Post()
  await post.save()
  post.id // server-assigned value
  post.createdAt // server-assigned value
```

```javascript
  var post = new Post();
  post.save().then(function(success) {
    post.id // server-assigned value
    post.createdAt // server-assigned value
  });
```

If a `Model` was instantiated with data from the server, `isPersisted` will return `true`. This means that we can assign IDs on the client without any adverse behavior. We can also manually mark objects as persisted for testing purposes:

```typescript
  let blog = new Blog({ id: 123 })
  blog.isPersisted // false
  await blog.save() // POST /blogs
  blog.isPersisted // true
  blog.id // 123

  // Manually mark an instance as persisted
  blog = new Blog({ id: 123 })
  blog.isPersisted = true
  await blog.save() // PUT /blogs/123
```

```javascript
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
```

Notably, **only dirty (changed) attributes will be sent to the server**. This prevents race conditions and unexpected side-effects. In the following example, `Post` has attributes `title`, `description`, and `createdAt`:

```typescript
  let post = (await Post.first())
  post.title = "updated"
  // ONLY title sent to the server
  await post.save()
  // Title is now synced with the server
  post.description = "updated"
  // ONLY description sent to the server
  await post.save()
```

```javascript
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
```

## Validations

JSONAPI Suite is already set up to return validation errors with a `422` response code and JSONAPI-compliant [errors payload](http://jsonapi.org/format/#errors). Those errors will be automatically assigned, and removed on subsequent requests:

```typescript
  let success = await post.save()
  console.log(success) // false
  post.errors.title // { message: "Can't be blank", ... }
  post.title = "no longer blank"
  success = await post.save()
  console.log(success) // true
  post.errors // {}
```

```javascript
  post.save().then(function(success) {
    console.log(success) // false
    post.errors.title // { message: "Can't be blank", ... }
    post.title = "no longer blank"
    post.save().then(function(success) {
      console.log(success); // true
      post.errors // {}
    });
  })
```

## Dirty Tracking

When an attribute has been modified, but has not yet been saved to the server, it is considered "dirty". Use `#isDirty()` to see if any attribute is dirty, use the `#changes()` method to see all dirty attributes.

```typescript
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
```

```javascript
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
```

> Remember, only dirty attributes are sent to the server when `#save()`
> is called.

`#isDirty()` *can* take into account relationships - just pass a string, array, or object or relationship names. A relationship is considered dirty if:

* Any objects in the relationship have dirty attributes
* An object was removed from a `hasMany` relationship
* An object was added to a `hasMany` relationship
* Any object within the relationship was replaced with a different
object.

```typescript
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
```

```javascript
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
```

If you need to reset dirty tracking, call `#reset()`

```typescript
  let post = await Post.first()
  post.title // "original"
  post.title = "changed"
  post.isDirty() // true
  post.reset()
  post.title // "changed"
  post.isDirty() // false
```

```javascript
  Post.first().then(function(post) {
    post.title; // "original"
    post.title = "changed";
    post.isDirty() // true
    post.reset();
    post.title; // "original"
    post.isDirty() // false
  });
```

## Nested Writes

You can write a `Model` and all of its relationships in a single request. Keep in mind normal dirty tracking rules still apply - nothing is sent to the server unless it is dirty.

```typescript
  let author = new Author()
  let comment = new Comment({ author })
  let post = new Post({ comments: [comment] })

  // post.save({ with: "comments" })
  // post.save({ with: ["comments", "blog"] })
  post.save({ with: { comments: 'author' }})
```

```javascript
  var author = new Author();
  var comment = new Comment({ author: author });
  var post = new Post({ comments: [comment] });

  // post.save({ with: "comments" })
  // post.save({ with: ["comments", "blog"] })
  post.save({ with: { comments: "author" }});
```

Use `model.isMarkedForDestruction = true` to delete the associated object. Use `model.isMarkedForDisassociation = true` to remove the association without deleting the underlying object:

```typescript
  let post = (await Post.includes("comments").first()).data
  post.comments[0].isMarkedForDestruction = true
  post.comments[1].isMarkedForDisassociation = true

  // destroys the first comment
  // disassociates the second comment
  await post.save({ with: "comments" })
```

```javascript
  Post.includes("comments").first().then(function(response) {
    var post = response.data;
    post.comments[0].isMarkedForDestruction = true;
    post.comments[1].isMarkedForDisassociation = true;

    // destroys the first comment
    // disassociates the second comment
    post.save({ with: "comments" })
  });
```

You may want to send *only* the `id` of the related object to the server - ensuring the models are associated without updating attributes by accident. Just add `.id` to the relationship name:

```typescript
  post.save({ with: "comments.id" })
```

```javascript
  post.save({ with: "comments.id" })
```

## Deferred Action

If your update or destroy action takes a long time then the server can respond with status code `202 Accepted` and include background job object in the payload.

Example response:
```http
HTTP/1.1 202 Accepted
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "background_jobs",
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "attributes": {
      "status": "pending"
    }
  }
}
```

You will need to give the model object a callback called `onDeferredDestroy` or `onDeferredUpdate`. Spraypaint will then call your callback with the deserialized object included in the payload.

```typescript
let person = new Person({ firstName: 'Jane' })
person.onDeferredUpdate = (job: any) => {
  handleBackgroundJob(job);
}
person.save()

person.onDeferredDestroy = (job: any) => {
  handleBackgroundJob(job);
}
person.destroy()
```

```javascript
const person = new Person({ firstName: 'Jane' });
person.onDeferredUpdate = (job) => {
  handleBackgroundJob(job);
};
person.save();

person.onDeferredDestroy = (job) => {
  handleBackgroundJob(job);
};
person.destroy();
```

  <h2 id="next">
    <a href="/js/middleware">
      NEXT:
      <small>Middleware</small>
      &raquo;
    </a>
  </h2>
