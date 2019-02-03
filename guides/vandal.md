---
layout: page
---

Vandal
==========

Vandal is the Graphiti UI. It's helpful for exploring data, testing and
generating URLs. To take Vandal for a spin, [view our sample app](https://jsonapi-employee-directory.herokuapp.com/vandal) (*initial load may take a second*).

<br />
<img width="100%" src="https://user-images.githubusercontent.com/55264/50740077-61dbe880-11b7-11e9-8919-34e1a48dd630.png">

<div markdown="1" class="toc col-md-3">

* 1 [Installation](#from-scratch)
  * [Via Gem](#installing-via-gem)
  * [Manual](#manual-installation)
* 2 [Usage](#usage)

</div>

<div markdown="1" class="col-md-8">

## 1 Installation

If you ran our [application template]({{site.github.url}}/guides/getting-started/installation),
you already have Vandal installed. Otherwise, you can
install from the `vandal_ui` gem, or manually install.

### Installing Via Gem

* Add the `vandal_ui` gem.
* Run `rake vandal:install`
* Mount the engine:

{% highlight ruby %}
# config/routes.rb
scope path: ApplicationResource.endpoint_namespace, defaults: { format: :jsonapi } do
  # ... routes ...
  mount VandalUi::Engine, at: '/vandal'
end
{% endhighlight %}

That's it! Vandal will dynamically generate a schema at `<api_namespace>/vandal/schema.json`, and you can view the UI at `<api_namespace>/vandal`.

### Manual Installation

[Vandal](https://github.com/graphiti-api/vandal) is a VueJS
application. Just grab the [dist files](https://github.com/graphiti-api/vandal/tree/master/dist) and put them anywhere you'd like.

Note that `index.html` has a placeholder, `__SCHEMA_PATH__`. Replace
this with a URL hosting your schema, and you'll be good to go.

## Usage

First, make sure your schema is properly generated. The schema is
generated whenever you run `rspec`. Remember that if you make changes,
you'll need to regenerate the schema before Vandal will see them.

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
