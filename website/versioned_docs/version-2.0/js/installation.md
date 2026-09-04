---
title: 'Installation'
sidebar_position: 2
---

### Installation

Installation is straightforward. Since we use `fetch` underneath the hood, we recommend installing alongside a `fetch` polyfill.

If using `yarn`:

```bash
$ yarn add spraypaint isomorphic-fetch
```

If using `npm`:

```bash
$ npm install spraypaint isomorphic-fetch
```

Now import it:

```typescript
import {
  Model,
  SpraypaintBase,
  Attr,
  BelongsTo,
  HasMany
  // etc
} from "spraypaint"
```

```javascript
const {
  SpraypaintBase,
  attr,
  belongsTo,
  hasMany
  // etc
} = require("spraypaint/dist/spraypaint")
```

...or, if you're avoiding JS modules, `spraypaint` will be available as a global in the browser.

### Typescript

Spraypaint works with modern TypeScript. Depending on your `tsconfig.json` settings, you may need a `!` after each attribute and relationship declaration:

```typescript
@Attr first_name!: string
@HasMany() positions!: Position[]
```

This is because of [Strict Class Initialization](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-2-7.html#strict-class-initialization) - `strictPropertyInitialization` expects every declared class field to be assigned in the constructor, which Spraypaint's decorators handle at runtime rather than at construction time. For the purposes of Spraypaint, we don't need this check. Remove the need for `!` (as the rest of these guides do) by setting

`"strictPropertyInitialization": false`

in `tsconfig.json`.

### Connecting to the API

Just like `ActiveRecord`, our models will inherit from a base class that holds connection information (`ApplicationRecord`, or `ActiveRecord::Base` in Rails < 5):

```typescript
@Model()
class ApplicationRecord extends SpraypaintBase {
  static baseUrl = "http://my-api.com"
  static apiNamespace = "/api/v1"
}
```

```javascript
const ApplicationRecord = SpraypaintBase.extend({
  static: {
    baseUrl: "http://my-api.com",
    apiNamespace: "/api/v1"
  }
})
```

All URLs follow the following pattern:

  * `baseUrl` + `apiNamespace` + `jsonapiType`

As you can see above, typically `baseUrl` and `apiNamespace` are set on a top-level `ApplicationRecord` (though any subclass can override). `jsonapiType`, however, is set per-model - see [Models](/js/models) for how to define it.

> **TIP**: Avoid CORS and use relative paths by setting `baseUrl` to `""`

> **TIP**: You can always use the `endpoint` option to override this pattern and set the endpoint manually.

#### Setting Application Name

It can be helpful to send the name of your client application in request headers. With this information, servers can keep track of which clients are hitting which APIs.

To do this:

```typescript
@Model()
class Person extends ApplicationRecord {
  static clientApplication = "sales-backend"
}
```

```javascript
const Person = ApplicationRecord.extend({
  static: {
    clientApplication: "sales-backend"
  }
})
```

  <h2 id="next">
    <a href="/js/models">
      NEXT:
      <small>Models</small>
      &raquo;
    </a>
  </h2>
