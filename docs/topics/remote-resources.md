---
title: 'Remote Resources'
---

## Overview {#overview}

Resources have a defined query contract, and connect together with [Links](/concepts/links). That contract doesn't care whether the sideloaded Resource lives in the same application, so we can point it at a separate service instead:

```ruby
has_many :comments,
  remote: 'http://blog-api.com/api/v1/comments'
```

Splitting an application into services tends to break down at the boundary between them: no consistent query interface, no consistent error handling, no types or backwards-compatibility checks. Graphiti was built to address exactly this - a defined query contract, an errors payload, and a schema with types and backwards-compatibility checks, all organized into RESTful Resources - so cross-service communication is automated rather than hand-rolled per integration.

> Note: Remote Resources are for **read** operations only. The exception
> is associating to an existing `belongs_to` remote entity.

> Note: We use [Faraday](https://github.com/lostisland/faraday) to hit
> the remote API. You must add `faraday` to your Gemfile to enable
> remote resources.

### How it Works {#how-it-works}

Let's take a simple association:

```ruby
class PostResource < ApplicationResource
  has_many :comments
end
```

This would generate a [Link](/concepts/links) for
lazy-loading comments:

```ruby
{
  related: "http://my-api.com/api/v1/comments?filter[post_id]=123"
}
```

Critically, **those same lazy-loading parameters are used when
eager-loading**:

```ruby
# under the hood
posts = PostResource.all.data
CommentResource.all(filter: { post_id: 123 })
```

OK, and we also know Resources support [any backend](/concepts/backends-and-models), and we can build an [Adapter](/topics/without-activerecord#adapters) if our backend supports common operations like filtering, sorting, and pagination.

So, that means we can build an Adapter that makes an HTTP request to another Graphiti Resource that lives in a separate API. That adapter is built into Graphiti and comes out-of-the-box: `Graphiti::Adapters::GraphitiAPI`

```ruby
class CommentResource < ApplicationResource
  self.remote = "http://my-api.com/api/v1/comments"
  # under-the-hood, this sets:
  # self.adapter = Graphiti::Adapters::GraphitiAPI
end
```

This Resource works as normal. We can execute queries:

```ruby
comments = CommentResource.all({
  sort: '-id',
  filter: { active: true }
})

# The model instances are OpenStructs
comments.data # => [#<OpenStruct>, #<OpenStruct>, ...]

# Those models reflect all the properties returned from the API:
comments.data.map(&:author) # => ["Jane Doe", "John Doe", ...]
```

And we can sideload just like we always do:

```ruby
class PostResource < ApplicationResource
  # Nothing to see here!
  has_many :comments
end
```

We'll still support Deep Querying - let's fetch the Post and its
active comments, ordered by `created_at`:

`/posts?include=comments&sort=comments.created_at&filter[active]=true`

Let's say `CommentResource` has an association to `Author`. If `AuthorResource` is defined in the remote API, we can fetch it as normal - no special configuration needed to fetch the `Post`, `Comment`s and `Author`s in a single request.

But maybe only `CommentResource` is remote, and `Authors` are local.
We need only define the association locally:

```ruby
class CommentResource < ApplicationResource
  self.remote = "http://my-api.com/api/v1/comments"

  belongs_to :author
end
```

Let's say we need to tweak the display of a property coming from the
remote API. Again, works just like normal:

```ruby
class CommentResource < ApplicationResource
  self.remote = "http://my-api.com/api/v1/comments"

  attribute :body, :string do
    @object.body.truncate(100)
  end
end
```

You only need to define attributes when overriding this logic -
otherwise we'll take them directly from the API response. This means you
don't have to update two repos and coordinate deploys - as soon as you
add a property to the remote API and deploy it, it will be reflected in
the local API response.

For the typical use case, we don't even *need* to create this Resource
class. The sideload definition accepts a `remote:` option, which will
create a Remote Resource under-the-hood:

```ruby
class PostResource < ApplicationResource
  has_many :comments, remote: 'http://my-api.com/api/v1/comments'
end

# Equivalent to:
#
# class PostResource < ApplicationResource
#   has_many :comments
# end
#
# class CommentResource < ApplicationResource
#   self.remote = 'http://my-api.com/api/v1/comments'
# end
```

> NOTE: When sending a request to a remote API, we request page size
> `999` so results don't get accidentally cut off. If you need
> successive requests, please [submit an issue](https://github.com/graphiti-api/graphiti/issues).

### Customizing {#customizing}

We use [Faraday](https://github.com/lostisland/faraday) under-the-hood,
which allows for various adapters and middleware. In addition:

#### Configure Timeout {#configure-timeout}

```ruby
class CommentResource < ApplicationResource
  self.remote = "..."

  # Customize faraday timeout
  self.timeout = 10
  self.open_timeout = 20
end
```

#### Configure Request {#configure-request}

```ruby
class CommentResource < ApplicationResource
  self.remote = "..."

  def make_request(url)
    # request here is from Faraday:
    #
    # conn.get do |req|
    #   yield req
    # end
    #
    super do |request|
      request.headers["Custom"] = "Header"
    end
  end
end
```

#### Configure Headers {#configure-headers}

By default we're going to *forward* the `Authorization` header of the request to the remote API. To override the default headers sent:

```ruby
# app/resources/comment_resource.rb
def request_headers
  { "Some-Foo" => "bar" }
end
```

### Error Handling {#error-handling}

If the remote API has an error, we want to re-raise that same error. But
unless you've enabled [displaying raw errors](/topics/error-handling#displaying-raw-errors), we won't be able to - the only information we have is what's returned from the API.

You're encouraged to display raw errors when an internal or privileged
user:

```ruby
rescue_from Exception do |e|
  handle_exception(e,  show_raw_error: current_user.developer?)
end
```

If you do this, we'll be able to re-raise the original error, including
stacktrace. If raw errors are not enabled, we'll raise whatever
information is given.

Both styles will be wrapped in `Graphiti::Errors::Remote`, so you can
differentiate between a local error and a remote one.

## Testing {#testing}

When testing a remote resource, we need to mock the API request and
response. Graphiti gives you a spec helper to do just that -
`include_context "remote api"`:

```ruby
describe 'comments' do
  include_context 'remote api'

  let(:api_response) do
    {
      data: [{
        id: '1',
        type: 'comments',
        attributes: { body: 'hello' }
      }]
    }
  end

  it 'does something' do
    url = 'http://my-api.com/api/v1/comments?page[size]=999'
    mock_api(url, api_response)
    # ... test ...
  end
end
```

This shows all the pieces needed to test remote APIs. We want to test

* The correct URL is hit
* When given a valid response, the rest of the flow works as expected.

> NOTE: if the remote relationship is a has_many, the API will need to
> return the foreign key as part of the response. Otherwise, we won't
> know how to associate these children to their parents.

Here's a slightly longer version, showing that `Post` can sideload `Comment`s:

```ruby
describe 'sideloading' do
  describe 'comments' do
    include_context 'remote api'

    let!(:post) { create(:post) }

    let(:api_response) do
      {
        data: [{
          id: '789',
          type: 'comments',
          attributes: { body: 'hello' }
        }]
      }
    end

    before do
      params[:include] = 'comments'
    end

    it 'does something' do
      url = "http://my-api.com/api/v1/comments"
      url += "?filter[post_id]=#{post_id}"
      mock_api(url, api_response)
      render
      sl = d[0].sideload(:comments)
      expect(sl.map(&:id)).to eq(['789'])
      expect(sl.map(&:jsonapi_type).uniq)
      .to eq(['comments'])
    end
  end
end
```

> Make sure to include `page[size]=999` in the test URL!
