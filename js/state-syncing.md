---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### State Syncing

You may have encountered state management libraries like [Flux](https://facebook.github.io/flux/docs/overview.html),
[Redux](https://redux.js.org) or [Vuex](https://vuex.vuejs.org/en/intro.html). These are fantastic libraries, but you likely won't need them with JSORM. As a full-fledged model layer, JSORM manages state for you, automatically.

If you opt-in to this feature:

{% highlight typescript %}
ApplicationRecord.sync = true
{% endhighlight %}

Instances will sync up whenever the server tells us about updated state.
Consider the scenario where an instance is initially loaded, then separately polled in the background:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let person = (await Person.find(1)).data

  let poll = () => {
    await Person.find(1)
    setTimeout(poll, 1000)
  }
  poll()
  {% endhighlight %}

  {% highlight javascript %}
  Person.find(1).then(function(response) {
    var person = response.data;
  });

  var poll = function() {
    Person.find(1);
    setTimeout(poll, 1000);
  }
  poll()
  {% endhighlight %}
</div>

Note that our `poll()` function **never assigns or updates `person`**.
But if the server returns an updated `name` attribute, **`person.name`
will be automatically updated**. This is true even if `person.name`
is bound in 17 different nested components.

Instances can still update their attributes independently - we only sync
when the server returns updated data:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
  let instanceA = (await Person.find(1)).data
  let instanceB = (await Person.find(1)).data

  instanceA.name // "Jane"
  instanceB.name // "Jane"

  instanceB.name = "Silvia"
  instanceA.name // "Jane"
  instanceB.name // "Silvia"

  await instanceB.save()
  instanceA.name // "Silvia"
  instanceB.name // "Silvia"
  {% endhighlight %}

  {% highlight javascript %}
  var instanceA, instanceB;
  Person.find(1).then(function(response) {
    instanceA = response.data;
  });
  Person.find(1).then(function(response) {
    instanceB = response.data;
  });

  instanceA.name // "Jane"
  instanceB.name // "Jane"

  instanceB.name = "Silvia"
  instanceA.name // "Jane"
  instanceB.name // "Silvia"

  instanceB.save().then(function() {
    instanceA.name // "Silvia"
    instanceB.name // "Silvia"
  });
  {% endhighlight %}
</div>

#### Gotchas

Under the hood, instances are listening for updates from a central data
store. This means that you'll want to remove listeners whenever you no
longer need the instance - otherwise it will never be garbage collected
properly. To remove a listener:

{% highlight typescript %}
instance.unlisten()
{% endhighlight %}

In practice, when developing in a SPA, you'll want to `#unlisten()`
whenever a view is destroyed and model instances no longer need to be referenced. If
you are using VueJS, this is done automatically by adding [jsorm-vue](https://github.com/jsonapi-suite/jsorm-vue)
to your application.

{% include highlight.html %}
