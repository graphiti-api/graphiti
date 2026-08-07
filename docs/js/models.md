---
title: 'Models'
sidebar_position: 3
---

### Defining Models

Once your `ApplicationRecord` base class is [connected to the API](/js/installation#connecting-to-the-api), define a model by giving it a `jsonapiType`:

```typescript
@Model()
class Person extends ApplicationRecord {
  static jsonapiType = "people"
}
```

```javascript
const Person = ApplicationRecord.extend({
  static: {
    jsonapiType: "people"
  }
})
```

With the above configuration, all `Person` endpoints will begin `http://my-api.com/api/v1/people`.

### Defining Attributes

`ActiveRecord` automatically sets attributes by introspecting database columns. We could do the same - `swagger.json` is our schema - but tend to agree with those who feel this aspect of `ActiveRecord` is a bit too "magical". In addition, explicitly defining our attributes can be used to track which applications are using which attributes of the API.

Though this is configurable, by default we expect the API to be `under_scored` and attributes to be `camelCased`.

```typescript
@Model()
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
```

```javascript
const attr = spraypaint.attr
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
```

Attributes can be marked read-only, so they are never sent to the server on a write request:

```typescript
@Attr({ persist: false }) createdAt: string
@Attr({ persist: false }) updatedAt: string
```

```javascript
attrs: {
  createdAt: attr({ persist: false }),
  updatedAt: attr({ persist: false })
}
```

### Defining Relationships

Just like `ActiveRecord`, there are `HasMany`, `BelongsTo`, and `HasOne` relationships:

```typescript
@Model()
class Dog extends ApplicationRecord {
  // ... code ...
  @BelongsTo() person: Person[]
}

class Person extends ApplicationRecord {
  // ... code ...
  @HasMany() dogs: Dog[]
}
```

```javascript
const hasMany = spraypaint.hasMany
const belongsTo = spraypaint.belongsTo

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
```

By default, we expect the relationship name to correspond to a pluralized `jsonapiType` on a separate `Model`. If your models don't use this convention, feel free to supply it explicitly:

```typescript
@Model()
class Dog extends ApplicationRecord {
  // ... code ...
  @BelongsTo('people') owner: Person[]
}

// alternatively, specify the class directly

class Dog extends ApplicationRecord {
  // ... code ...
  @BelongsTo(Person) owner: Person[]
}
```

```javascript
const Dog = ApplicationRecord.extend({
  // ... code ...
  attrs: {
    owner: belongsTo('people')
  }
})
```

Relationships can be:

* Assigned via constructor
* Assigned directly
* Automatically loaded via `.includes()` (see [reads](/js/reads))
* Saved in a single request `.save({ with: 'dogs' })` (see
[writes](/js/writes))

```typescript
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
```

```javascript
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
```

  <h2 id="next">
    <a href="/js/reads">
      NEXT:
      <small>Reads</small>
      &raquo;
    </a>
  </h2>
