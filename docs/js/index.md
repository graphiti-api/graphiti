---
title: 'Index'
sidebar_position: 1
---

<h1>
  Spraypaint
  <small>the isomorphic, framework-agnostic Graphiti ORM</small>
</h1>

### Why Spraypaint?

Contracts like JSONAPI and GraphQL treat the API like a database. When querying a database, we have two options:

  * Type the low-level query language directly (in the database world, this would be hand-typing SQL).
  * Use an ORM (like Rails's `ActiveRecord`, Phoenix's `Ecto`, Django's `DjangoORM`, or Node's `Sequelize`).

While both options have pros and cons, we tend to think ORMs have two overwhelming benefits: ***ease of use*** and ***composable queries***. We'll explore both these concepts in other sections.

So, we want a javascript ORM for our JSONAPI "database". Because `ActiveRecord` is arguably the most well-known ORM, we've tried to match its interface to make this library accessible to new users. That said, you'll find we've tried to favor *explicitness* over *implicitness* in order to avoid common `ActiveRecord` pitfalls.

            <span>Typescript</span>
              <span>Javascript</span>
```typescript
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
```

```javascript
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
```

### Where to Go Next

  * [Installation](/js/installation) - install spraypaint and connect it to your API
  * [Models](/js/models) - define models, attributes, and relationships
  * [Reads](/js/reads) - query your API with a composable, ActiveRecord-like interface
  * [Writes](/js/writes) - create, update, and destroy records
