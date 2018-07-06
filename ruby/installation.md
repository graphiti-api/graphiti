---
layout: page
---

{% include ruby-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Installation

JSONAPI Suite comes with a [Rails Application Template](http://guides.rubyonrails.org/rails_application_templates.html) to get you up and running quickly. To apply a template, you can pass either a URL or path to a file.

To generate a new application with the template:

{% highlight bash %}
$ rails new myapp --api -m https://raw.githubusercontent.com/jsonapi-suite/rails_template/master/all.rb
{% endhighlight %}

If needed, this command can be run by downloading `all.rb` and
pointing to it on your filesystem:

{% highlight bash %}
$ rails new myapp --api -m /path/to/all.rb
{% endhighlight %}

Run `git status` to see what the generator did.

### Breaking down the generator

The generator mostly installs gems and types some boilerplate for you.
But it can be helpful to understand everything that's going on and
customize to your needs (these are all customizable defaults).
Here's a line-by-line breakdown to explain what's going on. Use `git
status` to follow along.

* **app/controllers/application_controller.rb**
  * Mixes in `JsonapiSuite::ControllerMixin`. This includes relevant
  modules that decorate our controllers with methods like
  `render_jsonapi`.
  * Sets up global error handling, ensuring that we always render a
  JSONAPI-compliant [errors payload](http://jsonapi.org/format/#errors).
  Errors are handled through a DSL provided by [jsonapi_errorable](https://jsonapi-suite.github.io/jsonapi_errorable) - throw an error and use the DSL to customize response codes, messages, etc. In this code we'll follow a common Rails pattern and respond with `404` from `show` endpoints when a record is not found in the datastore.

* **config/routes.rb**
  * Configures routing so all our endpoints will be under `/<api_namespace>/v1`. The `<api_namespace>` is so you can point something like [HAProxy](http://www.haproxy.org) to various microservices based on the path. The `v1` sets up a simple versioning pattern.
  * Adds a `docs` resource. This for automatic [Swagger](https://swagger.io) documentation. Swagger requires a schema - `swagger.json` - that is generated from our `DocsController`. For more on this, see the [Autodocumentation]({{ site.github.url }}/ruby/swagger) section.

* **spec/rails_helper.rb**
  * Adds [jsonapi_spec_helpers](https://jsonapi-suite.github.io/jsonapi_spec_helpers). This gives us helper methods like `json_item` and `assert_payload` that lower the overhead of dealing with verbose JSONAPI responses. See more in the [Testing]({{ site.github.url }}/ruby/testing) section.
  * `JsonapiErrorable.disable!` disables global error handling before
  each test. This is because we usually don't want errors to be
  swallowed during tests. You can always turn it back on in a per-test
  basis with `JsonapiErrorable.enable!`
  * Adds [database_cleaner](https://github.com/DatabaseCleaner/database_cleaner) to ensure a clean database between tests.
  * Mixes in [factory_bot](https://github.com/thoughtbot/factory_bot_rails) methods. This gives us syntactic sugar of saying `create(:person)` instead of `FactoryBot.create(:person)`. See more in the [Testing]({{ site.github.url }}/ruby/testing) section.
  * Removes some fixture-specific configuration that is now handled by
  `database_cleaner`.

* **app/controllers/docs_controller/rb**
  * This is the controller that will generate our [Swagger](https://swagger.io) schema. It's using [Swagger Blocks](https://github.com/fotinakis/swagger-blocks) and [jsonapi_swagger_helpers](https://github.com/jsonapi-suite/jsonapi_swagger_helpers) under-the-hood. To learn more about Swagger documentation, see the the [Autodocumentation]({{ site.github.url }}/ruby/swagger) section.

* **public/api**
  * Adds a [Swagger UI]({{ site.github.url }}/ruby/swagger) to our project.

* **config/initializers/jsonapi.rb**
  * Requires the `ActiveRecord` adapter, which comes with the Suite. Comment this line if you'd like
  to avoid `ActiveRecord`. Learn more in the [Adapters]({{ site.github.url }}/ruby/alternate-datastores/adapters) section.

* **config/initializers/strong_resources.rb**
  * Stores templates that whitelist API inputs. Learn more in the
  [Strong Resources]({{ site.github.url }}/ruby/writes/strong-resources) section.

* **Rakefile**
  * Requires the swagger helpers library in order to run
  [backwards-compatibility]({{ site.github.url }}/ruby/backwards-compatibility) checks against production.

* **Gemfile**
  * We've added some dependencies, most of which are discussed in other
  sections:
    * `jsonapi-rails`: used for serialization, this is the
    rails-specific extension for [jsonapi-rb](http://jsonapi-rb.org)
    * `jsonapi_swagger_helpers`: used automatically generating Swagger
    documentation.
    * `jsonapi_spec_helpers`: easily deal with complex JSONAPI responses
    in tests.
    * `kaminari`: Default pagination gem.
    * `rspec-rails`: Testing framework.
    * `factory_bot_rails`: For easily seeding data in tests.
    * `faker`: for randomizing factory data.
    * `swagger-diff`: for backwards-compatibility checks.
    * `database_cleaner`: for cleaning the DB between tests.
