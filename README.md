### JsonapiCompliable

[![Build Status](https://travis-ci.org/jsonapi-suite/jsonapi_compliable.svg?branch=master)](https://travis-ci.org/jsonapi-suite/jsonapi_compliable)

[JSONAPI Suite Website](https://jsonapi-suite.github.io/jsonapi_suite)

[Documentation](https://jsonapi-suite.github.io/jsonapi_compliable)

Supported Rails versions: >= 4.1

### Upgrading to 0.11.x

Due to a backwards-incompatibility introduced in the underlying
[jsonapi-rb](http://jsonapi-rb.org) gem, specifying custom serializers
now works slightly differently.

Before:

```ruby
# app/serializers/serializable_post.rb

has_many :comments, class: SerializableSpecialComment
```

and/or

```ruby
render_jsonapi(post, class: SerializableSpecialPost)
```

This is now all handled at the controller level:

```ruby
render_jsonapi(post, class: {
  Post: SerializableSpecialPost,
  Comment: SerializableSpecialComment
})
```

### Upgrading to 0.10

`sideload_whitelist` has been moved from the resource to the controller:

```diff
class PostsController < ApplicationController
  jsonapi resource: PostResource do
-    sideload_whitelist({ index: [:foo] })
-  end
+  sideload_whitelist({ index: [:foo] })
end

# NEW
```

### Running tests

We support Rails >= 4.1. To do so, we use the [appraisal](https://github.com/thoughtbot/appraisal) gem. So, run:

```bash
$ bin/appraisal rails-4 bin/rspec
$ bin/appraisal rails-5 bin/rspec
```

Or run tests for all versions:

```bash
$ bin/appraisal bin/rspec
```

### Generating the Documentation

```bash
$ yard doc
$ yard server
```
