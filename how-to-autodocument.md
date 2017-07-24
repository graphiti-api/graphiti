---
layout: page
---

How to Autodocument with Swagger
==========

This suite uses DSLs to specify inputs (`strong_resources`, filters, etc), and outputs (`jsonapi-rb` serializers).
We can introspect that DSL to provide automatic documentation. Not only
does this save a lot of time, it ensures your code and documentation are
never out of sync.

Here we'll be using [swagger](https://swagger.io), a popular open-source
documentation framework.
<br />
<br />

<img width="100%" src="https://user-images.githubusercontent.com/55264/28526490-af7ce5a8-7055-11e7-88bf-1ce5ead32dd7.png" />

<br />
To get this UI, we need to install two things: a controller that
generates a <b>schema</b> (`swagger.json`), and a static website
in `public`. Let's start by adding dependencies:
<br />
<br />

```ruby
# Gemfile
# Below 'jsonapi_suite'
gem 'jsonapi_spec_helpers'
gem 'jsonapi_swagger_helpers'
```

<i>
  Note: here we're moving `jsonapi_spec_helpers` out of the
  test-specific bundle group. Introspecting spec helpers is part of
  autodocumenting, so we'll `require` them manually when our documentation
  controller is loaded.
</i>

Our web UI is a <a href="http://glimmerjs.com">Glimmer App</a>,
but we'll only deal with the already-compiled static files glimmer builds.
Let's copy those files and expose them to the web by putting them in
`public`:

```bash
$ mkdir -p public/api/docs && cd public/api/docs
$ git clone https://github.com/jsonapi-suite/swagger-ui.git && cp swagger-ui/prod-dist/* . && rm -rf swagger-ui
```

Our documentation will be accessible at `/api/docs`, so we put the files
in `public/api/docs`. You may want a different directory depending on
your own routing rules. In either case, our next step is to edit
`index.html`: make sure any javascript and css has the correct URL.
There are also a few configuration options, such as providing a link to
Github.

```javascript
window.CONFIG = {
  githubURL: 'http://github.com/user/repo',
  basePath: '/api' // basePath/swagger.json, basePath/v1/employees, etc
}
```

This static website will make a request to `/api/swagger.json`. Let's
build that endpoint now:

```bash
$ touch app/controllers/docs_controller.rb
```

```ruby
# config/routes.rb
scope path: '/api' do
  resources :docs, only: [:index], path: '/swagger'
  # ... code ...
end
```

Our `DocsController` uses [swagger-blocks](https://github.com/fotinakis/swagger-blocks) to generate
the swagger schema. Here's the minimal setup needed to configure
swagger:

```ruby
require 'jsonapi_swagger_helpers'

class DocsController < ActionController::API
  include JsonapiSwaggerHelpers::DocsControllerMixin

  swagger_root do
    key :swagger, '2.0'
    info do
      key :version, '1.0.0'
      key :title, '<YOUR APP NAME>'
      key :description, '<YOUR APP DESCRIPTION>'
      contact do
      key :name, '<YOU>'
      end
    end
    key :basePath, '/api'
    key :consumes, ['application/json']
    key :produces, ['application/json']
  end
end
```

That's it. Now, every time we add an endpoint, we can autodocument with
one line of code (below the `swagger_root` block):

```ruby
jsonapi_resource '/v1/employees'
```

This endpoint will be introspected for all RESTful actions, outputting
the full configuration. There are a few customization options:

```ruby
jsonapi_resource '/v1/employees',
  only: [:create, :index],
  except: [:destroy],
  descriptions: {
    index: "Some <b>additional</b> documentation"
  }
```

If you want additional attribute-level documentation, you can add this
to your spec payloads:

```ruby
key(:name, String, description: 'The full name, e.g. "John Doe"')
```

<br />
Will give you an output similar to:
<br />
<br />

<img width="430px" style="margin: 0 auto; display:block" src="https://user-images.githubusercontent.com/55264/28526856-c8938492-7056-11e7-8db2-2f25a3548e89.png" />

<br />
<br />

{% include highlight.html %}
