---
title: 'Vandal'
---

# Vandal
Vandal is the Graphiti UI. It's helpful for exploring data, testing and
generating URLs. To take Vandal for a spin, [view our sample app](https://jsonapi-employee-directory.herokuapp.com/vandal) (*initial load may take a second*).

<br />
<img width="100%" src="/assets/img/legacy/legacy-07aa104495.png" />



## Installation {#installation}

### Installing via Template {#installing-via-template}

If you ran our [application template](/getting-started/installation),
you already have Vandal installed. Check your routes to see it mounted.

### Installing via Gem {#installing-via-gem}

* Add the `vandal_ui` gem.
* Run `rake vandal:install`
* Mount the engine:

```ruby
# config/routes.rb
scope path: ApplicationResource.endpoint_namespace, defaults: { format: :jsonapi } do
  # ... routes ...
  mount VandalUi::Engine, at: '/vandal'
end
```

That's it! Vandal will dynamically generate a schema at `<api_namespace>/vandal/schema.json`, and you can view the UI at `<api_namespace>/vandal`.

### Manual Installation {#manual-installation}

[Vandal](https://github.com/graphiti-api/vandal) is a VueJS
application. Grab the [dist files](https://github.com/graphiti-api/vandal/tree/master/dist) and put them anywhere you'd like.

`index.html` has a placeholder, `__SCHEMA_PATH__`. Replace
this with a URL hosting your schema, and you'll be good to go.

## Usage {#usage}

First, make sure your schema is being correctly generated. You should
see Vandal make a request something like `/vandal/schema.json` - make
sure that looks correct. If it doesn't, you may need to bounce your
server.

After selecting an endpoint, use the left rail to configure your
request. Click a relationship once to include it in the response.
If a relationship is included, you can click any row in the table to
view related data.

Click a relationship twice and you can configure the deep query of
the associated Resource. In other words, if you're fetching Posts and
Comments, click `comments` twice to say things like "only active
comments should be returned".

When you hit 'submit', the top URL bar will change to reflect your query
and results will show in the center table.
