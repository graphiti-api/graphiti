---
layout: page
---

Quickstart
==========

##### Zero to API in 5 minutes

This quickstart will use Rails with ActiveRecord. Head to the guides
section for usage with alternate ORMs or avoiding Rails
completely.

If the below seems too "magical", don't worry - we're just applying some
sensible defaults to get started quickly.

# [Installation](#installation)

Let's start with a classic Rails blog. We'll use a [template](http://guides.rubyonrails.org/rails_application_templates.html) to handle some of the boilerplate. Just run this command and accept all the defaults for now:

{% highlight bash %}
$ rails new blog --api -m https://raw.githubusercontent.com/jsonapi-suite/rails_template/master/all.rb
{% endhighlight %}

Feel free to run `git diff` if you're interested in the
particulars; this is mostly just installing gems and including modules.

> Note: if a network issue prevents you from pointing to this URL
> directly, you can download the file and and run this command as `-m
> /path/to/all.rb`

# [Defining a Resource](#defining-a-resource)

A `Resource` defines how to query and persist your `Model`. In other
words: a `Model` is to the database as `Resource` is to the API. So
first, let's define our model:

{% highlight bash %}
$ bundle exec rails generate model Post title:string active:boolean
$ bundle exec rake db:migrate
{% endhighlight %}

Now we can use the built-in generator to define our `Resource`,
controller, and specs:

{% highlight bash %}
$ bundle exec rails g jsonapi:resource Post title:string active:boolean
{% endhighlight %}

You'll see a number of files created. If you open each one, you'll see
comments explaining what's going on. Head over to the
[tutorial](tutorial) for a more in-depth understanding. For now, let's
focus on two key concepts you'll see over and over again: inputs (via
[strong_resources](https://jsonapi-suite.github.io/strong_resources/)),
and outputs (via [jsonapi-rb](http://jsonapi-rb.org)).

Our **API Inputs** are defined in
`config/initializers/strong_resources.rb`. You can think of these as
[strong parameter](http://api.rubyonrails.org/v5.0/classes/ActionController/StrongParameters.html) templates.

{% highlight ruby %}
# config/initializers/strong_resources.rb
strong_resource :post do
  attribute :title, :string
  attribute :active, :boolean
end
{% endhighlight %}

Our **API Outputs** are defined in
`app/serializers/serializable_post.rb`. The DSL is very similar to
[active_model_serializers](https://github.com/rails-api/active_model_serializers) and full documentation can be found at [jsonapi-rb.org](http://jsonapi-rb.org):

{% highlight ruby %}
# app/serializers/serializable_post.rb
class SerializablePost < JSONAPI::Serializable::Resource
  type :posts

  attribute :title
  attribute :active
end
{% endhighlight %}

Now run your app!:

{% highlight bash %}
$ bundle exec rails s
{% endhighlight %}

Verify `http://localhost:3000/api/v1/posts` renders JSON correctly.
Now we just need data.

# [Seeding Data](#seeding-data)

We can seed data in two ways: the usual `db/seeds.rb`, or using an HTTP
client. Using the client helps get your feet wet with client-side
development, or you can avoid the detour and plow right ahead.

### [Seeding With Ruby](#seeding-with-ruby)

Edit `db/seeds.rb` to create a few `Post`s:

{% highlight ruby %}
Post.create!(title: 'My title!', active: true)
Post.create!(title: 'Another title!', active: false)
Post.create!(title: 'OMG! A title!', active: true)
{% endhighlight %}

And run the script:

{% highlight bash %}
$ bundle exec rake db:seed
{% endhighlight %}

### [Seeding With JS Client](#seeding-with-node)

There are a variety of [JSONAPI Clients](http://jsonapi.org/implementations/#client-libraries)
out there. We'll be using [JSORM](https://jsonapi-suite.github.io/jsorm)
which is built to work with Suite-specific functionality like nested
payloads. It can be used from the browser, but for now we'll call
it using a simple Node script.

Create the project:

{% highlight bash %}
$ mkdir node-seed && cd node-seed && touch index.js && npm init
{% endhighlight %}

Accept the default for all prompts. Now add the `JSORM` dependency, as
well as a polyfill for `fetch`:

{% highlight bash %}
$ npm install --save jsorm isomorphic-fetch
{% endhighlight %}

Add this seed code to `index.js`:

{% highlight javascript %}
require("isomorphic-fetch");
var jsorm = require("jsorm/dist/jsorm");

// setup code

var ApplicationRecord = jsorm.JSORMBase.extend({
  static: {
    baseUrl: "http://localhost:3000",
    apiNamespace: "/api/v1"
  }
});

var Post = ApplicationRecord.extend({
  static: {
    jsonapiType: "posts"
  },

  attrs: {
    title: jsorm.attr(),
    active: jsorm.attr()
  }
});

// seed code

var post1 = new Post({
  title: "My title!",
  active: true
});

var post2 = new Post({
  title: "Another title!",
  active: false
});

var post3 = new Post({
  title: "OMG! A title!",
  active: true
});

// Save sequentially only due to local development env
post1.save().then(() => {
  post2.save().then(() => {
    post3.save();
  });
});
{% endhighlight %}

This should be pretty straightforward if you're familiar with
`ActiveRecord`. We define `Model` objects, putting configuration on
class attributes. We instatiating instances of those Models, and call
`save()` to persist. For more information, see the [JSORM Documentation](https://jsonapi-suite.github.io/jsorm/).

Run the script:

{% highlight bash %}
$ node index.js
{% endhighlight %}

Now load `http://localhost:3000/api/v1/posts`. You should have 3 `Post`s in
your database!

![3_posts](assets/img/3_posts_json.png)

# [Querying](#querying)

Now that we've defined our `Resource` and seeded some data, let's see
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
  * Add one line of code:

{% highlight ruby %}
# app/resources/post_resource.rb
allow_filter :title
{% endhighlight %}
  * URL: `/api/v1/posts?filter[title]=My title!`
  * SQL: `SELECT * FROM posts WHERE title = "My title!"`
  * Any filter not whitelisted will raise `JsonapiCompliable::BadFilter`
  error.
  * All filter logic can be customized:

{% highlight ruby %}
# SELECT * from posts WHERE title LIKE 'My%'
allow_filter :title_prefix do |scope, value|
  scope.where(["title LIKE ?", "#{value}%"])
end
{% endhighlight %}
  * Customizations can be DRYed up and packaged into `Adapter`s.

* **Extra Fields**:
  * Sometimes you want to request additional fields not part of a normal
  response (perhaps they are computationally expensive).
  * This can be done like so:

{% highlight ruby %}
# app/serializers/serializable_post.rb
extra_attribute :description do
  @object.active? ? 'Active Post' : 'Inactive Post'
end
{% endhighlight %}

  * URL: `/api/v1/posts?extra_fields[posts]=description`
  * SQL: `SELECT * FROM posts`
  * You can conditionally eager load data or further customize this
  logic. See the tutorial for more.

* **Statistics**:
  * Useful for search grids - "Find me the first 10 active posts, and
  the total count of all posts".
  * One line of code to whitelist the stat:

{% highlight ruby %}
# app/resources/post_resource.rb
allow_stat total: [:count]
{% endhighlight %}

  * URL: `/api/v1/posts?stats[total]=count`
  * SQL: `SELECT count(*) from posts`
  * Combine with filters and the count will adjust accordingly.
  * There are a number of built-in stats, you can also add your own.
  * This is rendered in the `meta` section of the response:

    ![meta_total_count](assets/img/meta_total_count.png)

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

    ![error_payload](assets/img/error_payload.png)

  * Different errors can be customized with different response codes,
  JSON, and side-effects. View [jsonapi_errorable](https://jsonapi-suite.github.io/jsonapi_errorable/) for more.

# [Adding Relationships](#adding-relationships)

JSONAPI Suite supports full querying of relationships ("fetch me this
`Post` and 3 active `Comment`s sorted by creation date"), as well as
persistence ("save this `Post` and 3 `Comment`s in a single request").

### [Adding Relationships](#relationship-setup)

Let's start by defining our model:

{% highlight bash %}
$ bundle exec rails g model Comment post_id:integer body:text active:boolean
$ bundle exec rake db:migrate
{% endhighlight %}

{% highlight ruby %}
# app/models/post.rb
has_many :comments

# app/models/comment.rb
belongs_to :post, optional: true
{% endhighlight %}

...and corresponding `Resource` object:

{% highlight bash %}
$ bundle exec rails g jsonapi:resource Comment body:text active:boolean
{% endhighlight %}

Configure the relationship in `PostResource`:

{% highlight ruby %}
has_many :comments,
  foreign_key: :post_id,
  resource: CommentResource,
  scope: -> { Comment.all }
{% endhighlight %}

This code:

* Whitelists the relationship.
* Knows to link the objects via `post_id`.
* Will use `CommentResource` for querying logic (so we can say things
like "only return the latest 3 active comments")
* Uses an unfiltered base scope (`Comment.all`). If we wanted, we could
do things like `Comment.active` here to ensure only active comments are
ever returned.

You should now be able to hit `/api/v1/comments` with all the same
functionality as before. We just need to seed data.

Start by clearing out your database:

{% highlight bash %}
$ bundle exec rake db:migrate:reset
{% endhighlight %}

Again, you can seed your data using a NodeJS client or the traditional
`db/seeds.rb`.

#### [Seeding with NodeJS](#relationship-seeding-node)

Let's edit our `node-seed/index.js`. First add a `Comment` model:

{% highlight javascript %}
var Comment = ApplicationRecord.extend({
  static: {
    jsonapiType: 'comments'
  },

  attrs: {
    body: jsorm.attr(),
    active: jsorm.attr(),
    createdAt: jsorm.attr()
  }
});
{% endhighlight %}

...and add the relationship to `Post`:

{% highlight javascript %}
// within attrs
// ... code ...
comments: jsorm.hasMany()
// ... code...
{% endhighlight %}

Replace the existing `Post` instances with one `Post` and three
`Comment`s:

{% highlight javascript %}
var comment1 = new Comment({
  body: "comment one",
  active: true
});

var comment2 = new Comment({
  body: "comment two",
  active: false
});

var comment3 = new Comment({
  body: "comment three",
  active: true
});

var post = new Post({
  title: "My title!",
  active: true,
  comments: [comment1, comment2, comment3]
});

post.save({ with: ["comments"] });
{% endhighlight %}

Tell our controller it's OK to sidepost comments:

{% highlight ruby %}
# app/controllers/posts_controller.rb
strong_resource :post do
  has_many :comments
end
{% endhighlight %}

And tell our serializer it's OK to render comments:

{% highlight ruby %}
# app/serializers/serializable_post.rb
has_many :comments
{% endhighlight %}

Now run the script to persist the `Post` and its three `Comment`s in a
single request:

{% highlight bash %}
$ node node-seed/index.js
{% endhighlight %}

#### [Seeding With Ruby](#relationship-seeding-ruby)

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

## [Usage](#relationship-usage)

Now let's fetch a `Post` and filtered `Comment`s in a single request: `/api/v1/posts?include=comments`.

Any logic in `CommentResource` is available to us. Let's sort the
comments by `created_at` descending: `/api/v1/posts?include=comments&sort=-comments.created_at`. This should work out-of-the-box.

Now add a filter to `CommentResource`:

{% highlight ruby %}
allow_filter :active
{% endhighlight %}

That filter now works in two places:

* `/api/v1/comments?filter[active]=true`
* `/api/v1/posts?include=comments&filter[comments][active]=true`

This is why `Resource` objects exist: they provide an interface to
functionality shared across many different endpoints, with no extra
code.

# [What's Next](#whats-next)

We have a full CRUD API with robust querying functionality, and the
ability to combine relationships for both reads and writes. But what
happens when you need to customize the sorting logic? What about replacing
`ActiveRecord` with an alternate persistence layer, or avoiding Rails
altogether?

These are important topics that JSONAPI Suite was built to address. To
learn more about advanced usage and customization, we suggest following
the [tutorial](tutorial). There are also a number of how-tos on this
site, a good one to start with is [How to Use without ActiveRecord](how-to-use-without-activerecord)

For additional documentation, view the [YARD Docs](https://jsonapi-suite.github.io/jsonapi_compliable/).

For help with specific use cases, [join our Slack chat](https://join.slack.com/t/jsonapi-suite/shared_invite/enQtMjkyMTA3MDgxNTQzLWVkMDM3NTlmNTIwODY2YWFkMGNiNzUzZGMzOTY3YmNmZjBhYzIyZWZlZTk4YmI1YTI0Y2M0OTZmZGYwN2QxZjg)!

# [Bonus: Testing](#testing)

### [Installation](#testing-install)

Our generator applied some sensible defaults:

  * [Rspec](https://github.com/rspec/rspec-rails) Test runner
  * [jsonapi_spec_helpers](https://jsonapi-suite.github.io/jsonapi_spec_helpers) Helpers to parse and assert on JSONAPI payloads.
  * [factory_girl](https://github.com/thoughtbot/factory_girl) for
  seeding our test database with fake data.
  * [faker](https://github.com/stympy/faker) for generating fake values,
  such as e-mail addresses, names, avatar URLs, etc.
  * [database_cleaner](https://github.com/DatabaseCleaner/database_cleaner)
  to ensure our fake data gets cleaned up between test runs.

By default we rescue exceptions and return a valid [error response](http://jsonapi.org/format/#errors).
In tests, this can be confusing - we probably want to raise errors in
tests. So note our exception handling is disabled by default:

{% highlight ruby %}
# spec/rails_helper.rb
config.before :each do
  JsonapiErrorable.disable!
end
{% endhighlight %}

But you can enable it on a per-test basis:

{% highlight ruby %}
it "renders validation errors" do
  JsonapiErrorable.enable!
  post "/api/v1/employees", payload
  expect(validation_errors[:name]).to eq("can't be blank")
end
{% endhighlight %}

In following this guide, we generated `Post` and
`Comment` resources. Let's edit our [factories](https://github.com/thoughtbot/factory_bot) to seed randomized data:

{% highlight ruby %}
# spec/factories/post.rb
FactoryGirl.define do
  factory :post do
    title { Faker::Lorem.sentence }
    active { [true, false].sample }
  end
end

# spec/factories/comment.rb
FactoryGirl.define do
  factory :comment do
    body { Faker::Lorem.paragraph }
    active { [true, false].sample }
  end
end
{% endhighlight %}

Finally, we need to define a `Payload`. `Payload`s use a
`factory_girl`-style DSL to define expected JSON. A `Payload` compares a
`Model` instance and JSON output, ensuring:

* No unexpected keys
* No missing keys
* No unexpected value types
* No `null` values (this is overrideable)
* Model attribute matches JSON attribute
* This can all be customized. See [jsonapi_spec_helpers](https://github.com/jsonapi-suite/jsonapi_spec_helpers) for more.

Let's define our payloads now:

{% highlight ruby %}
# spec/payloads/post.rb
JsonapiSpecHelpers::Payload.register(:post) do
  key(:title, String)
  key(:active, [TrueClass, FalseClass])
end

# spec/payloads/comment.rb
JsonapiSpecHelpers::Payload.register(:comment) do
  key(:body, String)
  key(:active, [TrueClass, FalseClass])
  key(:created_at, Time)
end
{% endhighlight %}

### [Run](#testing-rub)

We can now run specs. Let's start with the `Post` specs:

{% highlight bash %}
$ bundle exec rspec spec/api/v1/posts
{% endhighlight %}

You should see five specs, with one failing (`spec/api/v1/posts/create_spec.rb`),
and one pending (`spec/api/v1/posts/update_spec.rb`).

The reason for the failure is simple: our payload defined in
`spec/payloads/post.rb` specifies that a `Post` JSON should include the
key `title`. However, that spec is currently creating a `Post` with no
attributes...which means in the response JSON, `title` is `null`. `null`
values will fail `assert_payload` unless elsewise configured.

So, let's update our spec to POST attributes, not just an empty object:

{% highlight ruby %}
let(:payload) do
  {
    data: {
      type: 'posts',
      attributes: {
        title: 'My title!',
        active: true
      }
    }
  }
end
{% endhighlight %}

Your specs should now pass. The only pending spec is due to a similar
issue - we need to specify attributes in `spec/api/v1/posts/update_spec.rb` as
well. Follow the comments in that file to apply a similar change.

You should now have 5 passing request specs! These specs spin up a fake
server, then execute full-stack requests that hit the database and
return JSON. You're asserting that JSON matches predefined payloads,
without `null`s or unknown key/values.

Go ahead and make the same changes to `Comment` specs to get 10 passing
request specs.

It's up to you how far you'd like to go with testing. Should you add a
new spec to `spec/api/v1/posts/index_spec.rb` every time you add a
filter with `allow_filter`? This boils down to personal preference and
tolerance of failures. Try adding a few specs following the generated
patterns to get a feel for what's right for you.

### [Bonus: Documentation](#documentation)

We can autodocument our code using [swagger documentation](https://swagger.io). Documenting an endpoint is one line of code:

{% highlight ruby %}
jsonapi_resource '/v1/employees'
{% endhighlight %}

Visit `http://localhost:3000/api/docs` to see the swagger documentation. Our custom UI will show all possible query parameters (including nested
relationships), as well as schemas for request/responses:

<img style="width: 100%" src="https://user-images.githubusercontent.com/55264/28526490-af7ce5a8-7055-11e7-88bf-1ce5ead32dd7.png" />

Our generator set up some boilerplate to enable this functionality, you
can learn more at: [How to Autodocument with Swagger](how-to-autodocument)

<br />
<br />
<br />
