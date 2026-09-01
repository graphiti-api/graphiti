---
title: 'Why REST?'
---

# Why REST?

Graphiti builds on REST rather than replacing it, which is worth a short explanation if you're weighing it against GraphQL.

The complaints that motivated GraphQL are real. REST APIs often make clients do several round trips and still hand back the wrong shape of data. But those are complaints about how REST APIs are usually built, not about REST. Add eager-loading and a schema to REST and the complaints go away, and you keep the parts of REST that are hard to get back once you've left: addressable URLs, HTTP caching, and Links that let the server change how a relationship resolves without breaking clients.

The other half is conventions. A GraphQL schema is hand-written per type, so filtering and sorting get reinvented on every team. One API spells it `name_contains`, another `name_LIKE`, another exposes no multisort at all. JSON:API already answers those questions, so `?filter[name][prefix]=Ja&sort=-created_at&page[size]=10` means the same thing on every endpoint of every Graphiti API. You define the Resource. The query interface follows from the attribute types.

That's the whole tradeoff: fewer decisions per endpoint, at the cost of a fixed request and response format.
