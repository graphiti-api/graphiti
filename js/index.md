---
layout: page
---

<h1>
  Spraypaint
  <small>the isomorphic, framework-agnostic Graphiti ORM</small>
</h1>

{% include js-toc.html %}

<div markdown="1" class="col-md-8 col-md-offset-1">
  > **Start here**: [Why Spraypaint?]({{ site.github.url }}/js/introduction)

  <div class="tabs">
    <div class="tab typescript">
      <span>Typescript</span>
    </div>
    <div class="tab javascript">
      <span>Javascript</span>
    </div>
  </div>
  <div markdown="1" class="code-tabs">
    {% highlight typescript %}
// Spraypaint is like "ActiveRecord in Javascript". It can:
//
// * Deeply nest reads and writes
// * Automatically handle validation errors
// * Replace *ux patterns
// * ...and much more!

// define models
@Model()
class ApplicationRecord extends SpraypaintBase {
  static baseUrl = "http://my-api.com"
  static apiNamespace = "/api/v1"
}

@Model()
class Person extends ApplicationRecord {
  static jsonapiType = "people"

  @Attr() firstName: string
  @Attr() lastName: string

  get fullName() {
    return `${this.firstName} ${this.lastName}`
  }
}

// execute queries
Person
  .where({ first_name: 'John' })
  .order({ created_at: 'desc' })
  .per(10).page(2)
  .includes({ jobs: 'company' })
  .select({ people: ['first_name', 'last_name'] })

// persist data
let person = new Person({ firstName: 'Jane' })
person.save()
    {% endhighlight %}

    {% highlight javascript %}
// Spraypaint is like "ActiveRecord in Javascript". It can:
//
// * Deeply nest reads and writes
// * Automatically handle validation errors
// * Replace *ux patterns
// * ...and much more!

var spnt = require('spraypaint/dist/spraypaint')

// define models
const ApplicationRecord = spnt.JSORMBase.extend({
  static: {
    baseUrl: 'http://my-api.com',
    apiNamespace: '/api/v1'
  }
})

const Person = ApplicationRecord.extend({
  attrs: {
    firstName: spnt.attr(),
    lastName: spnt.attr()
  },
  methods: {
    fullName: function() {
      return this.firstName + ' ' + this.lastName;
    }
  }
})

// execute queries
Person
  .where({ first_name: 'John' })
  .order({ created_at: 'desc' })
  .per(10).page(2)
  .includes({ jobs: 'company' })
  .select({ people: ['first_name', 'last_name'] })

// persist data
var person = new Person({ firstName: 'Jane' })
person.save()
    {% endhighlight %}
  </div>
</div>
