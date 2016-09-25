---
sectionid: swagger
sectionclass: h1
title: Swagger
number: 14
---

OK, we now have DSLs for both reads (`jsonapi { }`) and writes
(`strong_resources`). That means we can introspect those DSLs to
auto-generate our documentation!

Note: I'm going to assume you already have [swagger-ui](http://swagger.io/swagger-ui) set up, pointing to `/api/swagger_docs.json`.

We're going to build on top of [swagger-blocks](https://github.com/fotinakis/swagger-blocks), so let's go ahead and add our `DocsController`:

```ruby
# config/routes
scope '/api' do
  resources :docs, only: [:index], path: '/swagger_docs'
end

# app/controllers/docs_controller.rb
class DocsController < ApplicationController
  include JsonapiSwaggerHelpers::DocsControllerMixin

  swagger_root do
    key :swagger, '2.0'
  end
end
```

Now add `jsonapi_resource` for any endpoint you want to document:

```ruby
jsonapi_resource '/api/employees', tags: ['employees']
```

That's it. The suite will introspect the URL, figure out the correct
controller, introspect our DSL metadata and generate all the correct
swagger documentation. We'll even add some extra information for you,
like which relationships can be included:

<img src="img/endpoints.png" width="800px"/>
<img src="img/includes_filters.png" width="800px"/>
<img src="img/nested_relations.png" height="400px"/>

The default actions are `create`, `update`, `index`, `show`, and
`destroy`. You can customize using `only` and `except`. You can also
provide a custom description per action:

```ruby
jsonapi_resource '/api/employees',
  tags: ['employees'],
  except: [:destroy, :update],
  descriptions: {
    create: "Presence of name is validated"
  }
```

<div style="height: 3rem"></div>
{::options parse_block_html="true" /}
<div class='note info'>
###### More on Swagger Helper
  <div class='note-content'>
For documentation on swagger helpers, check out
[jsonapi_swagger_helpers](https://github.com/jsonapi-suite/jsonapi_swagger_helpers).
  </div>
</div>
<div style="height: 7rem"></div>
