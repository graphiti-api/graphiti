---
layout: page
---

Quickstart
==========

##### Zero to API in 10 minutes

This quickstart will use Rails with ActiveRecord. Head to the guides
section for usage with alternate ORMs or avoiding Rails
completely.

# <a name="installation" href='#installation'>Installation</a>

Let's start with a classic Rails blog:

```bash
$ rails new blog --api
```

Now add dependencies to your `Gemfile`:

```ruby
gem 'jsonapi_suite'
gem 'jsonapi-serializable', '0.1.3'
gem 'jsonapi-rails', '0.1.2'
gem 'kaminari'
```

The gem `kaminari` is optional (gems like `will_paginate` are also supported), but recommended if you'd like easy
pagination out-of-the-box.

Of course now we need to:

```bash
$ bundle install
```

Now that we've installed, let's bootstrap the suite. This will add a
few files and lines of code you don't need to worry about right now
(there are comments if you are curious):

```bash
$ bundle exec rails g jsonapi_suite:install
```

Finally, let's set up our routes so that we have a simple versioning
pattern baked-in:

```ruby
# config/routes.rb
scope path: '/api' do
  scope path: '/v1' do
    # your routes will go here
  end
end
```

This routing pattern is not required, but you will have to manually add
your own routing if you opt-out.

# <a name="defining-a-resource" href='#defining-a-resource'>Defining a Resource</a>

A `Resource` defines how to query and persist your `Model`. So first,
let's define our model:

```bash
$ bundle exec rails generate model Post title:string active:boolean
$ bundle exec rake db:migrate
```

Now we can use the built-in generator to define our `Resource`,
controller, and specs:

```bash
$ bundle exec rails g jsonapi:resource Post
```

You'll see a number of files created. If you open each one, you'll see
comments explaining what's going on. Head over to the
[tutorial](/tutorial) for a
more in-depth understanding.

There is a small bit of manual code: specifying the attributes of your
resource. We have to do this in three places: our API inputs (using our
version of `strong_parameters`), API outputs (using [jsonapi-rb](http://jsonapi-rb.org),
a library similar to `active_model_serializers`), and tests.

Start by specifying which attributes the user should be able to create
and update. This is all configurable, but for now let's let all `Post`
attributes in:

```ruby
# config/initializers/strong_resources.rb
strong_resource :post do
  attribute :title, :string
  attribute :active, :boolean
end
```

Now specify what attributes you want to serialize as part of the
response:

```ruby
# app/serializers/serializable_post.rb
class SerializablePost < JSONAPI::Serializable::Resource
  type :posts

  attribute :title
  attribute :active
end
```

And run your app!:

```
$ bundle exec rails s
```

Verify `http://localhost:3000/api/v1/posts` renders JSON correctly.
Now we just need data.

# <a name="seeding-data" href='#seeding-data'>Seeding Data</a>

We can seed data in two ways: the usual `db/seeds.rb`, or using an HTTP
client. Using the client helps get your feet wet with client-side
development, or you can avoid the detour and plow right ahead.

### <a name="seeding-with-ruby" href='#seeding-with-ruby'>Seeding With Ruby</a>

Edit `db/seeds.rb` to create a few `Post`s:

```ruby
Post.create!(title: 'My title!', active: true)
Post.create!(title: 'Another title!', active: false)
Post.create!(title: 'OMG! A title!', active: true)
```

And run the script:

```bash
$ bundle exec rake db:seed
```

### <a name="seeding-with-node" href='#seeding-with-node'>Seeding With JS Client</a>

There are a variety of [JSONAPI Clients](http://jsonapi.org/implementations/#client-libraries)
out there. We'll be using [JSORM](https://github.com/jsonapi-suite/jsorm),
which is built to work with Suite-specific functionality like nested
payloads. It can be used from the browser, but for now we'll call
it using a simple Node script.

Create the project:

```bash
$ mkdir node-seed && cd node-seed && touch index.js && npm init
```

Accept the default for all prompts. Now add the `JSORM` dependency, as
well as a polyfill for `fetch`:

```bash
$ npm install --save jsorm isomorphic-fetch
```

Add this seed code to `index.js`:

```javascript
require('isomorphic-fetch');
var jsorm = require('jsorm');

// setup code

var ApplicationRecord = jsorm.Model.extend({
  static: {
    baseUrl: 'http://localhost:3000',
    apiNamespace: '/api/v1'
  }
});

var Post = ApplicationRecord.extend({
  static: {
    jsonapiType: 'posts'
  },

  title: jsorm.attr(),
  active: jsorm.attr()
});

jsorm.Config.setup();

// seed code

var post1 = new Post({
  title: 'My title!',
  active: true
});

var post2 = new Post({
  title: 'Another title!',
  active: false
});

var post3 = new Post({
  title: 'OMG! A title!',
  active: true
});

// Save sequentially only due to local development env
post1.save().then(() => {
  post2.save().then(() => {
    post3.save();
  });
});
```

This should be pretty straightforward if you're familiar with
`ActiveRecord`. We define `Model` objects, putting configuration on
class attributes. We instatiating instances of those Models, and call
`save()` to persist. For more information, see the [JSORM Documentation](https://jsonapi-suite.github.io/jsorm/).

Run the script:

```bash
$ node index.js
```

Now load `http://localhost:3000/api/v1/posts`. You should have 3 `Post`s in
your database!

![3_posts]({{site.github.url}}/assets/img/3_posts_json.png)

# <a name="querying" href='#querying'>Querying</a>

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

    ```ruby
    # app/resources/post_resource.rb
    allow_filter :title
    ```
  * URL: `/api/v1/posts?filter[title]=My title!`
  * SQL: `SELECT * FROM posts WHERE title = "My title!"`
  * Any filter not whitelisted will raise `JsonapiCompliable::BadFilter`
  error.
  * All filter logic can be customized as one-offs, or packaged into an
  `Adapter`.

* **Extra Fields**:
  * Sometimes you want to request additional fields not part of a normal
  response (perhaps they are computationally expensive).
  * This can be done like so:

    ```ruby
    # app/serializers/serializable_post.rb
    extra_attribute :description do
      @object.active? ? 'Active Post' : 'Inactive Post'
    end
    ```

  * URL: `/api/v1/posts?extra_fields[posts]=description`
  * SQL: `SELECT * FROM posts`
  * You can conditionally eager load data or further customize this
  logic. See the tutorial for more.

* **Statistics**:
  * Useful for search grids - "Find me the first 10 active posts, and
  the total count of all posts".
  * One line of code to whitelist the stat:

    ```ruby
    # app/resources/post_resource.rb
    allow_stat total: [:count]
    ```

  * URL: `/api/v1/posts?stats[total]=count`
  * SQL: `SELECT count(*) from posts`
  * Combine with filters and the count will adjust accordingly.
  * There are a number of built-in stats, you can also add your own.
  * This is rendered in the `meta` section of the response:

    ![meta_total_count]({{site.github.url}}/assets/img/meta_total_count.png)

* **Error Handling**:
  * Your app will always render a JSONAPI-compliable error response.
  * Cause an error:

    ```ruby
    # app/controllers/posts_controller.rb
    def index
      raise 'foo'
    end
    ```

  * View the default payload:

    ![error_payload]({{site.github.url}}/assets/img/error_payload.png)

  * Different errors can be customized with different response codes,
  JSON, and side-effects. View [jsonapi_errorable](https://jsonapi-suite.github.io/jsonapi_errorable/) for more.

# <a name="adding-relationships" href='#adding-relationships'>Adding Relationships</a>

JSONAPI Suite supports full querying of relationships ("fetch me this
`Post` and 3 active `Comment`s sorted by creation date"), as well as
persistence ("save this `Post` and 3 `Comment`s in a single request").

### <a name="relationship-setup" href='#relationship-setup'>Adding Relationships</a>

Let's start by defining our model:

```bash
$ bundle exec rails g model Comment post_id:integer body:text active:boolean
$ bundle exec rake db:migrate
```

```ruby
# app/models/post.rb
has_many :comments

# app/models/comment.rb
belongs_to :post, optional: true
```

...and corresponding `Resource` object:

```bash
$ bundle exec rails g jsonapi:resource Comment
```

Configure the relationship in `PostResource`:

```ruby
has_many :comments,
  foreign_key: :post_id,
  resource: CommentResource,
  scope: -> { Comment.all }
```

This code:

* Whitelists the relationship.
* Knows to link the objects via `post_id`.
* Will use `CommentResource` for querying logic.
* Uses an unfiltered base scope (`Comment.all`)

Now specify the fields we want to output:

```ruby
# app/serializers/serializable_comment.rb
attribute :body
attribute :active
attribute :created_at
```

And the fields we accept on input:

```ruby
# config/initializers/strong_resources.rb
strong_resource :comment do
  attribute :body, :string
  attribute :active, :boolean
end
```

You should now be able to hit `/api/v1/comments` with all the same
functionality as before. We just need to seed data.

Start by clearing out your database:

```bash
$ bundle exec rake db:migrate:reset
```

Again, you can seed your data using a NodeJS client or the traditional
`db/seeds.rb`.

#### <a name="relationship-seeding-node" href='#relationship-seeding-node'>Seeding with NodeJS</a>

Let's edit our `node-seed/index.js`. First add a `Comment` model:

```javascript
var Comment = ApplicationRecord.extend({
  static: {
    jsonapiType: 'comments'
  },

  body: jsorm.attr(),
  active: jsorm.attr(),
  createdAt: jsorm.attr()
});
```

...and add the relationship to `Post`:

```javascript
// within class body
// ... code ...
comments: jsorm.hasMany(),
// ... code...
```

Replace the existing `Post` instances with one `Post` and three
`Comment`s:

```javascript
var comment1 = new Comment({
  body: 'comment one',
  active: true
});

var comment2 = new Comment({
  body: 'comment two',
  active: false
});

var comment3 = new Comment({
  body: 'comment three',
  active: true
});

var post = new Post({
  title: 'My title!',
  active: true,
  comments: [comment1, comment2, comment3]
});

post.save({ with: ['comments'] });
```

Tell our controller it's OK to sidepost comments:

```ruby
strong_resource :post do
  has_many :comments
end
```

Now run the script to persist the `Post` and its three `Comment`s in a
single request:

```bash
$ node node-seed/index.js
```

#### <a name="relationship-seeding-ruby" href='#relationship-seeding-ruby'>Seeding with Ruby</a>

Replace your `db/seeds.rb` with this code to persist one `Post` and
three `Comment`s:

```ruby
comment1 = Comment.new(body: 'comment one', active: true)
comment2 = Comment.new(body: 'comment two', active: false)
comment3 = Comment.new(body: 'comment three', active: true)

Post.create! \
  title: 'My title!',
  active: true,
  comments: [comment1, comment2, comment3]
```

## <a name="relationship-usage" href='#relationship-usage'>Usage</a>

Now let's fetch a `Post` and filtered `Comment`s in a single request: `/api/v1/posts?include=comments`.

Any logic in `CommentResource` is available to us. Let's sort the
comments by `created_at` descending: `/api/v1/posts?include=comments&sort=-comments.created_at`. This should work out-of-the-box.

Now add a filter to `CommentResource`:

```ruby
allow_filter :active
```

That filter now works in two places:

* `/api/v1/comments?filter[active]=true`
* `/api/v1/posts?include=comments&filter[comments][active]=true`

This is why `Resource` objects exist: they provide an interface to
functionality shared across many different endpoints, with no extra
code.

# <a name="whats-next" href='#whats-next'>What's Next</a>

We have a full CRUD API with robust querying functionality, and the
ability to combine relationships for both reads and writes. But what
happens when you need to customize the sorting logic? What replacing
`ActiveRecord` with an alternate persistence layer, or avoiding Rails
altogether?

These are important topics that JSONAPI Suite was built to address. To
learn more about advanced usage and customization, we suggest following
the [tutorial](/tutorial).

For additional documentation, view the [YARD Docs](https://jsonapi-suite.github.io/jsonapi_compliable/).
For help with specific use cases, join our Slack chat at https://jsonapi-suite.slack.com (email <richmolj@gmail.com> for an invite).

# <a name="testing" href='#testing'>Bonus: Testing</a>

### <a name="testing-install" href='#testing-install'>Installation</a>

Sharp eyes may have noticed we generated a number of spec files. Before
running these tests, we need to install and set up dependencies:

```ruby
# Gemfile
group :development, :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
end

group :test do
  gem 'database_cleaner'
  gem 'faker'
  gem 'jsonapi_spec_helpers', require: false
end
```

Only RSpec and `jsonapi_spec_helpers` are required, the rest are sensible defaults:

  * [factory_girl](https://github.com/thoughtbot/factory_girl) for
  seeding our test database with fake data.
  * [faker](https://github.com/stympy/faker) for generating fake values,
  such as e-mail addresses, names, avatar URLs, etc.
  * [database_cleaner](https://github.com/DatabaseCleaner/database_cleaner)
  to ensure our fake data gets cleaned up between test runs.

Now let's install everything and bootstrap RSpec:

```bash
$ bundle install && bundle exec rails g rspec:install
```

Edit `spec/rails_helper.rb` to add JSONAPI Suite [spec helpers](https://jsonapi-suite.github.io/jsonapi_spec_helpers):

```ruby
require 'jsonapi_spec_helpers'

# ... code ...
RSpec.configure do |config|
  # ... code ...
  config.include JsonapiSpecHelpers
end
```

And the `factory_girl` helpers:

```ruby
# ... code ...
config.include FactoryGirl::Syntax::Methods
```

And the `database_cleaner` glue code:

```ruby
# ... code ...
config.before(:suite) do
  DatabaseCleaner.strategy = :transaction
  DatabaseCleaner.clean_with(:truncation)
end

config.around(:each) do |example|
  begin
    DatabaseCleaner.cleaning do
      example.run
    end
  ensure
    DatabaseCleaner.clean
  end
end
```

In following this guide, we generated `Post` and
`Comment` resources. But - to avoid the overhead of testing during a
quickstart - we didn't have `factory_girl` installed when we ran those
generators. Let's go ahead and add those files now:

```ruby
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
```

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

```ruby
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
```

### <a name="testing-run" href='#testing-rub'>Run</a>

We can now run specs. Let's start with the `Post` specs:

```bash
$ bundle exec rspec spec/api/v1/posts
```

You should see five specs, with one failing (`spec/api/v1/posts/create_spec.rb`),
and one pending (`spec/api/v1/posts/update_spec.rb`).

The reason for the failure is simple: our payload defined in
`spec/payloads/post.rb` specifies that a `Post` JSON should include the
key `title`. However, that spec is currently creating a `Post` with no
attributes...which means in the response JSON, `title` is `null`. `null`
values will fail `assert_payload` unless elsewise configured.

So, let's update our spec to POST attributes, not just an empty object:

```ruby
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
```

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

### <a name="documentation" href='#documentation'>Bonus: Documentation</a>

We can autodocument our code using [swagger documentation](https://swagger.io). Once you follow the [installation instructions](/how-to-autodocument), documenting an endpoint is one line of code:

```ruby
jsonapi_resource '/v1/employees'
```

Our custom UI will show all possible query parameters (including nested
relationships), as well as schemas for request/responses:

<img style="width: 100%" src="https://user-images.githubusercontent.com/55264/28526490-af7ce5a8-7055-11e7-88bf-1ce5ead32dd7.png" />

<br />
<br />
<br />

{% include highlight.html %}
