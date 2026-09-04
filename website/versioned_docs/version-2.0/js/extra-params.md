---
title: 'Extra Params'
sidebar_position: 10
---

### Extra Params

Sometimes you need to submit params that are not standard jsonapi params. One great example would be
`https://yourdomain.com/users?debug=true` which is not a param for the `UserResource` you may have, but
might enable functionality in your controller as needed.

Invoking it is pretty straightforward, just invoke `extraParams` and pass in params and values you wish
to add to your API call when executed.


```typescript
YourRecord.extraParams({ debug: true })
```

One common way to use this globally is to put this into a base class so it can be chained as part of 
every resource.

```typescript
  @Model
  export class ApplicationRecord extends SpraypaintBase {
    static withDebug<T extends ApplicationRecord>(): Scope<T> {
      return this.extraParams({ debug: true }) as Scope<T>;
    }
  }
  // unfortunately you will need to pass in the 
  // implementing class' type as a generic
  UserRecord.withDebug<UserRecord>().all()
```
```javascript
  const ApplicationRecord = SpraypaintBase.extend({
    static: {
      withDebug: () => this.extraParams({ debug: true });
    }
  })
  UserRecord.withDebug().all()
```
