---
layout: page
---

{% include js-header.html %}
{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
### Installation

Installation is straightforward. Since we use `fetch` underneath the
hood, we recommend installing alongside a `fetch` polyfill.

If using `yarn`:

{% highlight bash %}
$ yarn add jsorm isomorphic-fetch
{% endhighlight %}

If using `npm`:

{% highlight bash %}
$ npm install jsorm isomorphic-fetch
{% endhighlight %}

Now import it:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
import {
  Model,
  JSORMBase,
  Attr,
  BelongsTo,
  HasMany
  // etc
} from "jsorm"
{% endhighlight %}

{% highlight javascript %}
const {
  JSORMBase,
  attr,
  belongsTo,
  hasMany
  // etc
} = require("jsorm/dist/jsorm")
{% endhighlight %}
</div>

...or, if you're avoiding JS modules, `jsorm` will be available as a global in
the browser.

### Defining Models

#### Connecting to the API

Just like `ActiveRecord`, our models will inherit from a base class that
holds connection information (`ApplicationRecord`, or
`ActiveRecord::Base` in Rails < 5):

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
class ApplicationRecord extends JSORMBase {
  static baseUrl = "http://my-api.com"
  static apiNamespace = "/api/v1"
}
{% endhighlight %}

{% highlight javascript %}
const ApplicationRecord = JSORMBase.extend({
  static: {
    baseUrl: "http://my-api.com",
    apiNamespace: "/api/v1"
  }
})
{% endhighlight %}

All URLs follow the following pattern:

  * `baseUrl` + `apiNamespace` + `jsonapiType`

As you can see above, typically `baseUrl` and `apiNamespace` are set on
a top-level `ApplicationRecord` (though any subclass can override).
`jsonapiType`, however, is set per-model:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
class Person extends ApplicationRecord {
  static jsonapiType = "people"
}
{% endhighlight %}

{% highlight javascript %}
const Person = ApplicationRecord.extend({
  static: {
    jsonapiType: "people"
  }
})
{% endhighlight %}
</div>

With the above configuration, all `Person` endpoints will begin
`http://my-api.com/api/v1/people`.

> **TIP**: Avoid CORS and use relative paths by simply setting `baseUrl` to
`""`

> **TIP**: You can always use the `endpoint` option to override this pattern
and set the endpoint manually.

#### Defining Attributes

`ActiveRecord` automatically sets attributes by introspecting database
columns. We could do the same - `swagger.json` is our schema - but tend
to agree with those who feel this aspect of `ActiveRecord` is a bit too
"magical". In addition, explicitly defining our attributes can be used
to track which applications are using which attributes of the API.

Though this is configurable, by default we expect the API to be
`under_scored` and attributes to be `camelCased`.

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
class Person extends ApplicationRecord {
  // ... code ...
  @Attr() firstName: string
  @Attr() lastName: string
  @Attr() age: number

  get fullName() : string {
    return `${this.firstName} ${this.lastName}`
  }
}

let person = new Person({ firstName: "John" })
person.firstName // "John"
person.lastName = "Doe"
person.attributes // { firstName: "John", lastName: "Doe" }
person.fullName // "John Doe"
{% endhighlight %}

{% highlight javascript %}
const attr = jsorm.attr
const Person = ApplicationRecord.extend({
  // ... code ...
  attrs: {
    firstName: attr(),
    lastName: attr(),
    age: attr()
  },
  methods: {
    fullName: function() {
      return this.firstName + " " + this.lastName;
    }
  }
})

var person = new Person({ firstName: "John" })
person.firstName // "John"
person.lastName = "Doe"
person.attributes // { firstName: "John", lastName: "Doe" }
person.fullName() // "John Doe"
{% endhighlight %}
</div>

#### Defining Relationships

Just like `ActiveRecord`, there are `HasMany`, `BelongsTo`, and
`HasOne` relationships:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
class Dog extends ApplicationRecord {
  // ... code ...
  @BelongsTo() person: Person[]
}

class Person extends ApplicationRecord {
  // ... code ...
  @HasMany() dogs: Dog[]
}
{% endhighlight %}

{% highlight javascript %}
const hasMany = jsorm.hasMany
const belongsTo = jsorm.belongsTo

const Person = ApplicationRecord.extend({
  // ... code ...
  attrs: {
    dogs: hasMany()
  }
})

const Dog = ApplicationRecord.extend({
  // ... code ...
  attrs: {
    person: belongsTo()
  }
})
{% endhighlight %}
</div>

By default, we expect the relationship name to correspond to a
pluralized `jsonapiType` on a separate `Model`. If your models don't
use this convention, feel free to supply it explicitly:

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
{% highlight typescript %}
class Dog extends ApplicationRecord {
  // ... code ...
  @BelongsTo('people') owner: Person[]
}

// alternatively, specify the class directly

class Dog extends ApplicationRecord {
  // ... code ...
  @BelongsTo(Person) owner: Person[]
}
{% endhighlight %}

{% highlight javascript %}
const Dog = ApplicationRecord.extend({
  // ... code ...
  attrs: {
    owner: belongsTo('people')
  }
})
{% endhighlight %}
</div>

Relationships can be:

* Assigned via constructor
* Assigned directly
* Automatically loaded via `.includes()` (see [reads](/js/reads))
* Saved in a single request `.save({ with: 'dogs' })` (see
[writes](/js/writes))

{% include js-code-tabs.html %}
<div markdown="1" class="code-tabs">
  {% highlight typescript %}
let dog = new Dog({ name: "Fido" })
let person = new Person({ dogs: [dog] })
person.dogs[0].name // "Fido"

let person = new Person()
person.dogs = [dog]
person.dogs[0].name // "Fido"

// Will auto-create Dog instance
let person = new Person({ dogs: [{ name: "Scooby" }] })
person.dogs[0].name // "Scooby"

let person = (await Person.includes('dogs')).data
person.dogs // array of Dog instances from the server
  {% endhighlight %}

  {% highlight javascript %}
var dog = new Dog({ name: "Fido" })
var person = new Person({ dogs: [dog] })
person.dogs[0].name // "Fido"

let person = new Person()
person.dogs = [dog]
person.dogs[0].name // "Fido"

// Will auto-create Dog instance
var person = new Person({ dogs: [{ name: "Scooby" }] })
person.dogs[0].name // "Scooby"

Person.includes('dogs').then((response) => {
  var person = response.data
  person.dogs // array of Dog instances from the server
})
  {% endhighlight %}
</div>

<div class="clearfix">
  <h2 id="next">
    <a href="{{site.github.url}}/js/reads">
      NEXT:
      <small>Reads</small>
      &raquo;
    </a>
  </h2>
</div>
