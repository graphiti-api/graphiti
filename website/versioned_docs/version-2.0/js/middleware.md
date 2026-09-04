---
title: 'Middleware'
sidebar_position: 6
---

### Middleware

Middleware is helpful whenever you want to globally intercept request.
This is accomplished by assigning a `MiddlewareStack` to your `ApplicationRecord`. Each stack has `beforeFilters` and `afterFilters` where you can globally modify requests. If you `throw("abort")`, the
promise will be rejected.

Example: redirecting to the login page every time the server returns `401`:

```typescript
  import { MiddlewareStack } from 'spraypaint'

  let middleware = new MiddlewareStack()
  middleware.afterFilters.push((response, json) => {
    if (response.status === 401) {
      window.location.href = "/login"
      throw("abort")
    }
  })

  ApplicationRecord.middlewareStack = middleware
```

```javascript
  var MiddlewareStack = spraypaint.MiddlewareStack;

  var middleware = new MiddlewareStack();
  middleware.afterFilters.push(function(response, json) {
    if (response.status === 401) {
      window.location.href = "/login";
      throw("abort");
    }
  });

  ApplicationRecord.middlewareStack = middleware;
```

Example: adding a custom header before the request is sent:

```typescript
  import { MiddlewareStack } from 'spraypaint'

  let middleware = new MiddlewareStack()
  middleware.beforeFilters.push((url, options) => {
    options.headers["CUSTOM-HEADER"] = "whatever"
  })

  ApplicationRecord.middlewareStack = middleware
```

```javascript
  var MiddlewareStack = spraypaint.MiddlewareStack;

  var middleware = new MiddlewareStack();
  middleware.beforeFilters.push(function(url, options) {
    options.headers["CUSTOM-HEADER"] = "whatever";
  });

  ApplicationRecord.middlewareStack = middleware;
```

  <h2 id="next">
    <a href="/js/authentication">
      NEXT:
      <small>Authentication</small>
      &raquo;
    </a>
  </h2>
