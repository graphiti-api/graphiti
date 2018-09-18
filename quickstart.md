---
layout: page
---

Quickstart
==========

##### Zero to API in 5 minutes

This quickstart will use Rails with ActiveRecord to give an overview of
Graphiti functionality on familiar ground. For a more in-depth breakdown, head to the
[**Guides**]({{site.github.url}}/guides).

If the below seems too "magical", don’t worry - we’re just applying some
sensible defaults to get started quickly.

## Installation

Let's start with a classic Rails blog. We'll use a [template](http://guides.rubyonrails.org/rails_application_templates.html) to handle some of the boilerplate. Just run this command and accept all the defaults for now:

{% highlight bash %}
$ rails new blog --api -m https://raw.githubusercontent.com/graphiti-api/graphiti_rails_template/master/all.rb
{% endhighlight %}

Feel free to run `git diff` if you're interested in the
particulars; this is mostly just installing gems and including modules.

> Note: if a network issue prevents you from pointing to this URL
> directly, you can download the file and and run this command as `-m
> /path/to/all.rb`

## Defining a Resource

A [**Resource**]({{site.github.url}}/guides/concepts/resources) defines how to query and persist your [**Model**]({{site.github.url}}/guides/concepts/backends-and-models). In other
words: a Model is to the database as Resource is to the API. So
first, let's define our Model:

{% highlight bash %}
$ bundle exec rails generate model Post title:string upvotes:integer active:boolean
$ bundle exec rails db:migrate
{% endhighlight %}

Now we can use the built-in [generator]({{site.github.url}}/guides/concepts/resources#generators) to define our Resource,
corresponding [**Endpoint**]({{site.github.url}}/guides/concepts/endpoints), and
[**Integration Tests**]({{site.github.url}}/guides/concepts/testing).

{% highlight bash %}
$ bundle exec rails g graphiti:resource Post title:string upvotes:integer active:boolean
{% endhighlight %}

You'll see a number of files created. Now run your app!:

{% highlight bash %}
$ bundle exec rails s
{% endhighlight %}

Verify `http://localhost:3000/api/v1/posts` renders JSON correctly.
Now we just need data.

##### Seeding Data

Edit `db/seeds.rb` to create a few `Post`s:

{% highlight ruby %}
Post.create!(title: 'My title', upvotes: 10, active: true)
Post.create!(title: 'Another title', upvotes: 20, active: false)
Post.create!(title: 'OMG! A title', upvotes: 30, active: true)
{% endhighlight %}

And run the script:

{% highlight bash %}
$ bundle exec rails db:seed
{% endhighlight %}

Now load `http://localhost:3000/api/v1/posts`. You should have 3 `Post`s in
your database!

{% comment %}![3_posts]({{site.github.url}}/assets/img/3_posts_json.png){% endcomment %}

<hr />

# Querying

Now that we've defined our Resource and seeded some data, let's see
what query functionality we have. We've listed all `Post`s at
`http://localhost:3000/api/v1/posts`. Let's see what we can do:

* **Sort**
  * By title, ascending:
    * URL: `/api/v1/posts?sort=title`
    * SQL: `SELECT * FROM posts ORDER BY title ASC`
  * By title, descending:
    * URL: `/api/v1/posts?sort=-title`
    * SQL: `SELECT * FROM posts ORDER BY title DESC`

* **Paginate**:
  * 2 Per page:
    * URL: `/api/v1/posts?page[size]=2`
    * SQL: `SELECT * FROM posts LIMIT 2`
  * 2 Per page, second page:
    * URL: `/api/v1/posts?page[size]=2&page[number]=2`
    * SQL: `SELECT * FROM posts LIMIT 2 OFFSET 2`

* **Sparse Fieldsets**:
  * Only render `title`, not `active`:
    * URL: `/api/v1/posts?fields[posts]=title`
    * SQL: `SELECT * from posts` (*optimizing this query is on the roadmap*)

* **Filter**:
  * Simple:
    * URL: `/api/v1/posts?filter[title]=my title`
    * SQL: `SELECT * FROM posts WHERE title = "My title!"`
  * Case Sensitive:
    * URL: `/api/v1/posts?filter[title][eql]=My title`
    * SQL: `SELECT * FROM posts WHERE lower(title) = "my title!"`
  * Prefix:
    * URL: `/api/v1/posts?filter[title][prefix]=my`
    * SQL: `SELECT * FROM posts WHERE lower(title) LIKE 'my%'`
  * Suffix:
    * URL: `/api/v1/posts?filter[title][suffix]=title`
    * SQL: `SELECT * FROM posts WHERE lower(title) LIKE '%title!'`
  * Contains:
    * URL: `/api/v1/posts?filter[title][match]=itl`
    * SQL: `SELECT * FROM posts WHERE lower(title) LIKE '%itl%'`
  * Greater Than:
    * URL: `/api/v1/posts?filter[upvotes][gt]=20`
    * SQL: `SELECT * FROM posts WHERE upvotes > 20`
  * Greater Than or Equal To:
    * URL: `/api/v1/posts?filter[upvotes][gte]=20`
    * SQL: `SELECT * FROM posts WHERE upvotes >= 20`
  * Less Than:
    * URL: `/api/v1/posts?filter[upvotes][lt]=20`
    * SQL: `SELECT * FROM posts WHERE upvotes < 20`
  * Less Than or Equal To:
    * URL: `/api/v1/posts?filter[upvotes][lte]=20`
    * SQL: `SELECT * FROM posts WHERE upvotes <= 20`
  * Any filter not whitelisted will raise `JsonapiCompliable::BadFilter`
  error.
  * [All filter logic can be customized]({{site.github.url}}/guides/concepts/resources#filter)
  * Customizations can be DRYed up and packaged into **Adapters**.

* **Extra Fields**:
  * Sometimes you want to request additional fields not part of a normal
  response (perhaps they are computationally expensive).
  * This can be done like so:

{% highlight ruby %}
# app/resources/post_resource.rb
extra_attribute :description, :string do
  @object.active? ? 'Active Post' : 'Inactive Post'
end
{% endhighlight %}

  * URL: `/api/v1/posts?extra_fields[posts]=description`
  * SQL: `SELECT * FROM posts`
  * You can conditionally eager load data or further customize this
  logic.

* **Statistics**:
  * Useful for search grids - "Find me the first 10 active posts, and
  the total count of all posts".
  * URL: `/api/v1/posts?stats[total]=count`
  * SQL: `SELECT count(*) from posts`
  * Combine with filters and the count will adjust accordingly.
  * There are a number of built-in stats, you can also add your own.
  * This is rendered in the `meta` section of the response:

    ![meta_total_count]({{site.github.url}}/assets/img/meta_total_count.png)
  * [View Documentation]({{site.github.url}}/guides/concepts/resources#statistics)

* **Error Handling**:
  * Your app will always render a JSONAPI-compliable error response.
  * Cause an error:

{% highlight ruby %}
# app/controllers/posts_controller.rb
def index
  raise 'foo'
end
{% endhighlight %}

  * View the default payload:

    ![error_payload]({{site.github.url}}/assets/img/error_payload.png)

  * Different errors can be customized with different response codes,
  JSON, and side-effects.

## Persisting

Resources can Create, Update, and Delete (and you can persist multiple
Resources in a single request). The best way to observe this behavior is
to take a look at the tests the generator created. One example:

{% highlight ruby %}
# spec/api/v1/employees/create_spec.rb
subject(:make_request) do
  jsonapi_post "/api/v1/employees", payload
end

describe 'basic create' do
  let(:payload) do
    {
      data: {
        type: 'employees',
        attributes: {
          first_name: 'Jane'
        }
      }
    }
  end

  it 'works' do
    expect(EmployeeResource).to receive(:build).and_call_original
    expect {
      make_request
    }.to change { Employee.count }.by(1)
    expect(response.status).to eq(201)
  end
end
{% endhighlight %}

Read more about [Persistence]({{site.github.url}}/guides/concepts/resources#persisting) and
[Testing Persistence]({{site.github.url}}/guides/concepts/testing#writes).

## Adding Relationships

Let’s start by defining our Model:

{% highlight bash %}
$ bundle exec rails g model Comment post_id:integer body:text active:boolean
$ bundle exec rails db:migrate
{% endhighlight %}

{% highlight ruby %}
# app/models/post.rb
has_many :comments

# app/models/comment.rb
belongs_to :post
{% endhighlight %}

...and corresponding Resource object:

{% highlight bash %}
$ bundle exec rails g graphiti:resource Comment body:string active:boolean created_at:datetime
{% endhighlight %}

Configure the relationship in `PostResource`:

{% highlight ruby %}
# app/resources/post_resource.rb
has_many :comments
{% endhighlight %}

And allow filtering Comments based on the Post `id`:

{% highlight ruby %}
# app/resources/comment_resource.rb
attribute :post_id, :integer, only: [:filterable]
{% endhighlight %}

This code:

* Allows eager-loading the relationship.
  * URL: `/api/v1/posts?include=comments`
  * SQL: `SELECT * FROM comments WHERE post_id = 123`
* Generates a [**Link**]({{site.github.url}}/guides/concepts/links) for
lazy-loading.
* Will use `CommentResource` for querying logic (so we can [Deep
Query]({{site.github.url}}/guides/concepts/resources#deep-queries), e.g.
"only return the latest 3 active comments").
* By default, this will generate the query `CommentResource.all(filter:
{ post_id: 123 })`, but [relationships can be customized]({{site.github.url}}/guides/concepts/resources#relationships)

You should now be able to hit `/api/v1/comments` with all the same
functionality as before. We just need to seed data.

#### Seeding Relationships

Start by clearing out your database:

{% highlight bash %}
$ bundle exec rails db:migrate:reset
{% endhighlight %}

Replace your `db/seeds.rb` with this code to persist one `Post` and
three `Comment`s:

{% highlight ruby %}
comment1 = Comment.new(body: 'comment one', active: true)
comment2 = Comment.new(body: 'comment two', active: false)
comment3 = Comment.new(body: 'comment three', active: true)

Post.create! \
  title: 'My title!',
  active: true,
  comments: [comment1, comment2, comment3]
{% endhighlight %}

And run it:

{% highlight bash %}
$ bundle exec rails db:seed
{% endhighlight %}

## Relationship Usage

Now let's fetch a `Post` and filtered `Comment`s in a single request:

`/api/v1/posts?include=comments`

Any logic in `CommentResource` is available to us. Let's sort the
comments by `created_at` descending:

`/api/v1/posts?include=comments&sort=-comments.created_at`.

Logic from `CommentResource` is accessible at the `/api/v1/comments`
endpoint, and reusable when eager-loading Comments at `/api/v1/posts:`

* `/api/v1/comments?filter[active]=true`
* `/api/v1/posts?include=comments&filter[comments.active]=true`

This is why Resource objects exist: they provide an interface to
reuse code across multiple Endpoints.

Also note: just as we can query a graph of Resources in a single
request, we can *persist* a graph of Resources in a single request. See
[Sideposting]({{site.github.url}}/guides/concepts/resources#sideposting).

## What's Next

We have a full CRUD API with robust querying functionality, and the
ability to combine relationships for both reads and writes. But what
happens when you need to customize the sorting logic? What about replacing
`ActiveRecord` with an alternate persistence layer, or avoiding Rails
altogether?

These are important topics that Graphiti was built to address. To
learn more about advanced usage and customization, we suggest following
the [**Tutorial**]({{site.github.url}}/tutorial) and reading through the
[**Guides**]({{site.github.url}}/guides).

For help with specific use cases, [**join our Slack chat**](https://join.slack.com/t/jsonapi-suite/shared_invite/enQtMjkyMTA3MDgxNTQzLWVkMDM3NTlmNTIwODY2YWFkMGNiNzUzZGMzOTY3YmNmZjBhYzIyZWZlZTk4YmI1YTI0Y2M0OTZmZGYwN2QxZjg)!

## Testing

This Quickstart is meant to get you up-and-running quickly, so we didn't
write tests. But in Graphiti **testing is the easiest, most pleasant way
to develop your application**.

Even if you're not normally a TDDer, we highly recommend reading through
our [**Integration Testing Guide**]({{site.github.url}}/guides/concepts/testing).

<br />
<br />
