---
title: 'Authentication'
sidebar_position: 7
---

### Authentication

Spraypaint supports [JSON Web Tokens](https://jwt.io/introduction). These can
be set manually, or automatically fetched from `localStorage`.

To set manually:

```typescript
ApplicationRecord.jwt = 'myt0k3n'
```
> All requests will now send the header:<br />
> `Authorization: Token token="myt0k3n"`.

To set via `localStorage`, store the token with a key of `jwt` and it will be set automatically. To customize the `localStorage` key:

```typescript
ApplicationRecord.jwtStorage = "authtoken"
```

...or to opt-out of `localStorage` altogether:

```typescript
ApplicationRecord.jwtStorage = false
```

You can control the format of the header that is sent to the
server:

```typescript
  class ApplicationRecord extends SpraypaintBase {
    // ... code ...
    static generateAuthHeader(token) {
      return `Bearer ${token}`
    }
  }
```

```javascript
  var ApplicationRecord = SpraypaintBase.extend({
    // ... code ...
    static: {
      generateAuthHeader: function(token) {
        return "Bearer " + token;
      }
    }
  });
```

Finally, if your server returns a refreshed JWT within the `X-JWT` header, it will be used in all subsequent requests (and `localStorage`
will be updated automatically if you're using it).

  <h2 id="next">
    <a href="/js/state-syncing">
      NEXT:
      <small>State Syncing</small>
      &raquo;
    </a>
  </h2>
