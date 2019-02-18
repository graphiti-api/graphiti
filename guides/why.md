---
layout: page
---

Why Graphiti
============

I have enourmous respect for GraphQL. I also believe there is a
fundamental flaw in its design.

Let's remember [why people like GraphQL](https://dev.to/smizell/why-people-like-graphql-221c) in the first place: because it addressed common frustrations with REST APIs:

> *[We] heard from integrators that our REST API also wasn't very flexible. It sometimes required two or three separate calls to assemble a complete view of a resource. It seemed like our responses simultaneously sent too much data and didn’t include data that consumers needed.*
>
> \- ["The Github Graph API"](https://githubengineering.com/the-github-graphql-api), GitHub Engineering

GraphQL solves real problems. It's flaw is that it solved these
problems using zero-sum thinking: we must
abandon the existing paradigm and forge a new one. It's GraphQL
versus REST, one or the other. [REST is dead, long live GraphQL](https://medium.freecodecamp.org/rest-apis-are-rest-in-peace-apis-long-live-graphql-d412e559d8e4).

Graphiti instead approaches the problem using [positive-sum thinking](http://aturon.github.io/2018/06/02/listening-part-2):

> *Positive-sum thinking is how we embrace pluralism while retaining a coherent vision and set of values...A zero-sum view would assume that apparent oppositions are fundamental, e.g., that appealing to the JS crowd inherently hurts the C++ one. A positive-sum view starts by seeing different perspectives and priorities as legitimate and worthwhile, with a faith that* **by respecting each other in this way, we can find strictly better solutions than had we optimized solely for one perspective.**
>
> \- ["Listening and Trust"](http://aturon.github.io/2018/06/02/listening-part-2), Aaron Turon

GraphQL optimized around REST's shortcomings, and in doing so it dropped
REST's advantages. There is no need for such a zero-sum tradeoff. We can take
everything great about GraphQL and build it ***on top of*** REST (and
HTTP!), instead of replacing it altogether. We can have our cake and eat it too.

## REST

You'll find plenty of GraphQL [blog posts](https://blog.apollographql.com/graphql-vs-rest-5d425123e34b) that define REST like so:

<br />

<p align="center">
  <img width="80%" src="https://user-images.githubusercontent.com/55264/52901666-6a6f0800-31d4-11e9-81be-4bc23a7c26aa.png" />
</p>

<br />

It's true that many REST APIs work this way, but this is not REST. While there's
endless debate around which APIs are considered "RESTful", I don't think
we need to look much further than what the letters actually stand for:

> **Representational State Transfer**. *This sentence is not only what REST stands for, it is also the tiniest possible description of what REST actually means...It is not a standard, rather a style describing the act of transfering a state of something by its representation.*
>
> *Let's consider this:*
>
> *Marcus is a farmer. He has a ranch with 4 pigs, 12 chickens and 3 cows. He is now simulating a REST API while I am the client. If I want to request the current state of his farm using REST I just ask him: "State?"*
>
> *Marcus answers: "4 pigs, 12 chickens, 3 cows".
This is the most simple example of Representional State Transfer. Marcus transfered the state of his farm to me using a representation. The representation of the farm is the plain sentence: "4 pigs, 12 chickens, 3 cows".*
>
> *So lets get to the next level. How would I tell Marcus to add 2 cows to his farm the REST way?
Maybe tell him: "Marcus, please add 2 cows to your farm".*
>
> *Do you think this was REST? Are we transfering state by its representation here? **NO!** This was calling a remote procedure. The procedure of adding 2 cows to the farm.*
>
> *Marcus sadly answers: "400, Bad Request. What do you mean?"*
>
> *So lets try this again. How would we do this the REST way? What was the representation again? It was "4 pigs, 12 chickens, 3 cows". Ok. so let's try this again transfering the representation...*
>
> *me: "Marcus, ... 4 pigs, 12 chickens, 5 cows ... please!".*
> *Marcus: "Alright !".*
> *me: "Marcus, ... what is your state now?".*
> *Marcus: "4 pigs, 12 chickens, 5 cows".*
> *me: "Ahh, great!"*
> *See? It was really not that hard and it was REST.*
>
> \- ["Why REST Is So Important"](http://www.beabetterdeveloper.com/2013/07/why-rest-is-so-important.html), Gregor Riegler

In other words, **this is REST**:

<p align="center">
  <img width="50%" src="https://user-images.githubusercontent.com/55264/52913247-36561e80-328a-11e9-98ea-5e743920d317.gif" />
</p>

We're moving an object from the server to the client, possibly modifying
that object, then moving back to the server.

Pretty simple right? Here's how we might implement this in GraphQL:

{% highlight typescript %}
type CreateEmployeeInput {
  name: String
  age: Int
}

type CreateEmployeePayload {
  employee: Employee
}

type UpdateEmployeeInput {
  employeeId: ID!
  name: String
  age: Int
}

type UpdateEmployeePayload {
  employee: Employee
}

type DestroyEmployeeInput {
  id: ID!
}

type DestroyEmployeePayload {
  employee: Employee
}

type Employee {
  id: ID!
  name: String
}

createEmployee(input: CreateEmployeeInput!): CreateEmployeePayload
updateEmployee(input: UpdateEmployeeInput!): UpdateEmployeePayload
destroyEmployee(input: DestroyEmployeeInput!): DestroyEmployeePayload

employee(id: ID!): Employee
{% endhighlight %}

The first thing to note is that GraphQL is super badass at describing
fields and types. The next thing to note is that fields and types are
the wrong abstraction.

Defining a schema like this allows bespoke, fine-grained detail. If we
wanted, the `CreateEmployeePayload` could be different than the
`UpdateEmployeePayload` - same for inputs like `CreateEmployeeInput` and
`UpdateEmployeeInput`. If we wanted other actions, like
`promoteEmployee` or `deactivateEmployee`, they would be easy to add and
follow the same basic constructs.

This is **RPC** - hand-crafted, custom requests. We have a high level of
**configuration** but a low level of **convention**. Not only will
developers have to spend more time hand-crafting these requests, but
patterns are likely to diverge from one API to the next, from team to
team, as time moves on. In fact, the above is really a best-case
scenario with common naming convention of `create/update/destroy` - the
Github API adds verbs like `add`, `remove`, `lock`, `move` and more.

The benefit of REST over RPC is conventions. Conventions cause increased
productivity and consistency (leading to fewer misunderstandiings and
chances for bugs). Let's start thinking in REST, and see where it takes
us.

In REST, we know the input and output is always the Resource:

{% highlight typescript %}
type Employee {
  id: ID!
  name: string
}

createEmployee(input: Employee): Employee
updateEmployee(input: Employee!): Employee
destroyEmployee(input: Employee!): Employee

employee(id: ID): Employee
{% endhighlight %}

OK, a little tighter. But there's actually no reason to type this out
each time - we can assume developers are already familiar with the
convention.

{% highlight typescript %}
type Employee {
  id: ID!
  name: string
}

createEmployee
updateEmployee
destroyEmployee

employee(id: ID)
{% endhighlight %}

Getting there. OK, and we know we're dealing with an Employee, and we
know we won't have custom verbs like `promote` or `remove` - we're
moving objects here, and nothing else (if that throws you for a mental
loop, see [this presentation by Derek Prior](https://www.youtube.com/watch?v=HctYHe-YjnE), Engineering Manager at
GitHub).

{% highlight typescript %}
type Employee {
  id: ID!
  name: string
}

create
update
destroy
show // employee(id: ID)
index // employee()
{% endhighlight %}

By adopting conventions, we not only removed boilerplate - we removed
the chance of subtle inconsistencies. This is better for both providers
and consumers of the API.

We're just getting started.

The above schema covers basic CRUD. But we probably want to filter data, right? Let's say we want to return all employees with a given name:

{% highlight typescript %}
employee(id: ID, name: String)
{% endhighlight %}

Again, we're seeing chances for inconsistency. What's the `name`
parameter - straight equality? Case sensitive? Contains? I guess we
could throw a bunch of suffixes at it:

{% highlight typescript %}
employee(id: ID, name_eq: String, name_suffix: String, name_prefix:
String, name_contains: String, name_not_eq: String, name_not_suffix:
String, name_prefix: String, name_not_prefix: String)
{% endhighlight %}

Works, but a bit unwieldy...and again, likely to diverge wildly across
implementations.

What about sorting? Should we do it similar to the [Github API](https://developer.github.com/v4/explorer/)?:

{% highlight typescript %}
enum OrderDirection {
  ASC
  DESC
}

enum EmployeeOrderField {
  ID
  NAME
}

type EmployeeOrder {
  field: EmployeeOrderField!
  direction: OrderDirection
}

employee(orderBy: EmployeeOrder)
{% endhighlight %}

Or should we do it like [How to
GraphQL](https://www.howtographql.com/graphql-js/8-filtering-pagination-and-sorting/)?:

{% highlight typescript %}
enum EmployeeOrderByInput {
  id_ASC
  id_DESC
  name_ASC
  name_DESC
}

employee(orderBy: EmployeeOrderByInput)
{% endhighlight %}

We have divergent APIs right off the bat, and neither one supports
multisort.

Let's take a step back and think RESTfully. REST doesn't have a query
specification, but it does have this Resource concept. **Instead of
thinking in fields and types, what if we thought in Resources**?:

Resources have attributes (fields) with corresponding types (String, Int, etc). We'd
probably want to filter and sort by these attributes right? We might add
some additional filters and sorts, we might want to opt-out of others,
but querying a Resource by its attributes serves as a reasonable
baseline.

If we have an attribute and it's a `string`, we know we're
talking about operators like `suffix` and `prefix`, but an `integer`
attribute would want operators like `greater_than` and `less_than`.

OK, so really we don't need to define *inputs* and *outputs* - those can
be assumed by convention. What we really need to define is the **Resource**.

Welcome to Graphiti:

{% highlight ruby %}
class EmployeeResource < ApplicationRecord
  attribute :name, :string, sortable: true, filterable: true
  attribute :age, :integer, writable: false
end
{% endhighlight %}

With nothing but this Resource definition and some assumed conventions,
we get all this behavior out of the box:

* Create
* Update
* Delete
* Read
  * Filter
    * String (`name`)
      * `eq` (case sensitive)
      * `eql` (case insensitive)
      * `prefix`
      * `suffix`
      * `match`
      * `not_*` (`not_eq`, `not_prefix`, etc)
    * Dates and Numbers (`age`)
      * `eq`
      * `gt` (greater than)
      * `lt` (less than)
      * `gte` (greater than/equal to)
      * `lte` (less than/equal to)
  * Sort / Multisort
  * Paginate
  * Fieldsets

There's more to this than a bunch of out-of-the-box standards and
behavior. If we thought only in Fields and Types, we'd use GraphiQL to
see something like:

<br />

<p align="center">
  <img width="30%" src="https://user-images.githubusercontent.com/55264/52915902-78418d80-32a7-11e9-8515-021312258400.png" />
</p>

<br />

But if we thought in Resources...well, REST is super popular for
websites, websites have forms, so what if we...

<br />

<p align="center">
  <img width="40%" src="https://user-images.githubusercontent.com/55264/52916024-e3d82a80-32a8-11e9-8bb6-07ac9bf988dc.png" />
</p>

<br />

This screenshot is from [Vandal](https://graphiti-api.github.io/graphiti/guides/vandal), the Graphiti UI.

Because we started with a better abstraction, we ended with a better
visualization. As a marketer-turned-programmer myself, I really
appreciate when data exploration tools like this are friendly to
less-technical users. A user of Vandal doesn't need to know about `Connection`s
or `Edge`s, they just need to click around. I like that my product owner and I can walk
through the domain together, validating concepts and solidifying a shared
understanding.

We even get schema benefits. Schemas are great for tooling and
backwards-compatibility checks...but when they are oriented around
Fields and Types, they can only tell you so much. When they are oriented
around Resources, they can expose less-obvious concepts. Maybe we sort
Employees by `created_at` by default:

{% highlight bash %}
{
  "name": "EmployeeResource",
  "type": "employees",
  "attributes": { ... },
  "default_sort": [{ "created_at": "desc" }],
  ...
}
{% endhighlight %}

Because this is specified in the schema, not only are clients more
informed, but changing this default would raise a backwards-compatibility
error:

{% highlight bash %}
EmployeeResource: default sort changed from [{:created_at=>"desc"}] to [{:last_name=>"asc"}].
{% endhighlight %}

## Graphs

You may be thinking, "*OK, but REST only works for a single object. I'll
have to make multiple requests, and be right back where I started. I
need GraphQL to solve this problem*".

Not true.

Years before GraphQL came out, respected developers from different
companies and backgrounds came together and began the discussion on how to improve REST
APIs. This wasn't a project pushed by a hundred-billion dollar
company; it was an organic, community-driven effort. The result was the [JSON:API](https://jsonapi.org) standard,
which tackled granular queries long ago:

> (*Quick aside: I've always found the name of this project hilariously
awkward, easy to confuse with any API outputting JSON. But you could say
the same about GraphQL! Just as JSON:API isn't the only API standard
outputting JSON, GraphQL isn't the only Graph Query Language - in fact,
you could call JSON:API a Graph Query Language as well!*)

{% highlight ruby %}
# GET /employees?include=positions

{
  data: {
    id: "123",
    type: "employees",
    attributes: { name: "Kayla Webb" },
    relationships: {
      positions: {
        data: { id: "456", type: "positions" }
      }
    }
  },
  included: [
    {
      id: "456",
      type: "positions",
      attributes: { title: "Engineer" }
    }
  ]
}
{% endhighlight %}

Wonky payload, right? OK, first of all, don't be scared. In Graphiti,
you can add `.json` to the URL and output a more traditional flat
structure:

{% highlight ruby %}
{
  data: {
    id: "123",
    name: "Jeesoo Ryoo",
    positions: [{ id: "456", title: "Engineer" }]
  }
}
{% endhighlight %}

You can absolutely develop in Graphiti this way, but you'd be giving up
some smart things JSON:API does. One example is de-duplicating each node
in the graph: if we're listing 100 `Post`s and they all have the same
`Author`, you'll have to render that `Author` 100 times. JSON:API would
only render it once.

Another is the `type/id` combo:

<p align="center">
  <div style="width: 500px;margin:auto">
<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">Namely, those constraints are that all entities must be addressable top level by type and ID. (Very similar to JSON:API in this respect.)</p>&mdash; Tom Dale (@tomdale) <a href="https://twitter.com/tomdale/status/786951015945895936?ref_src=twsrc%5Etfw">October 14, 2016</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
  </div>
</p>

There's a bunch of reasons this is important, but one I've always been
partial to is websockets. This `type/id` combo allows us to uniquely
identify records once they've been loaded in JS memory. So, every time a
Resource is saved we can push its state (JSON representation) to clients
with a websocket. Here I am randomly updating a bunch of backend data,
and watching the UI update in real-time.

<p align="center">
  <img width="80%" src="https://user-images.githubusercontent.com/55264/38929932-042408da-42dc-11e8-93ec-16b0f9b62da3.gif" />
</p>
<br />

This took only a handful of lines of code, all of which could be
packaged into a library to make this automatic.

Another example is lazy-loading data with Links:

<p align="center">
  <div style="width: 500px;margin:auto">
    <blockquote class="twitter-tweet" data-conversation="none" data-lang="en"><p lang="en" dir="ltr">A GraphQL response is going to be as slow as the slowest subquery it has to execute to build the response.</p>&mdash; Tom Dale (@tomdale) <a href="https://twitter.com/tomdale/status/786952448799825921?ref_src=twsrc%5Etfw">October 14, 2016</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
  </div>
</p>

Instead of loading everying up-front, we want to defer loading for
performance reasons. Maybe we want to render our `Employee` detail page
super quick, and we don't need to list the `Position`s until the user
clicks something.

You can do this in GraphQL, but you need to bake logic into the client,
which means changing the logic would break clients (read more about
this in the [Links Guide](https://graphiti-api.github.io/graphiti/guides/concepts/links)).
Luckily, REST and JSON:API are optimized for lazy-loading:

{% highlight ruby %}
# ...
positions: {
  links: {
    related: 'http://example.com/api/positions?filter[employee_id]=123'
  }
}
# ...
{% endhighlight %}

Graphiti generates these Links between Resources automatically. If you
change the logic, we'll update the Link - clients can simply follow the
link, and we can change logic server-side with no breakage.

There's a bunch of other great stuff about JSON:API, but that is a
topic for another day.

Anything you could do with a single Resource, you can do with multiple
Resources. In other words, we can fetch an `Employee`, and their
`Positions` - but only `active` positions where the title starts with
`Eng`, ordered by `created_at`. This is called **Deep Querying**.

The point here is that REST doesn't mean multiple requests. Sure, our
state is now a graph of objects instead of a single object, but there's
no need for a wholesale revamp. In fact, we don't need to change much at
all.

<p align="center">
  <img width="30%" src="https://user-images.githubusercontent.com/55264/52920466-a68c9080-32da-11e9-823c-1ff275db40f6.jpg" />
</p>

Just as we can **query** multiple Resources at once, we can also
**persist** multiple objects at once.

When persisting in REST, we send the same object back to the server
alongside a verb. That verb tells us if we're creating, updating (part
or whole), or deleting. Same thing here. Let's specify the verb
alongside the relationship:

{% highlight ruby %}
# ...
positions: {
  data: { id: "456", type: "positions", method: "destroy" }
}
# ...
{% endhighlight %}

There are only 4 possible verbs:

* `create`
* `update`
* `destroy`
* `disassociate`

Oh, and we'll run everything within a transaction, throwing in
conventions for data validation as well:

{% highlight ruby %}
# Response code 422

{
  code:  'unprocessable_entity',
  status: '422',
  title: "Validation Error",
  detail: "Name can't be blank",
  source: { pointer: '/data/attributes/name' },
  meta: {
    attribute: :name,
    message: "can't be blank",
    code: :blank
  }
}
{% endhighlight %}

Earlier, we covered how REST was optimized for lazy-loading. Graphiti
builds on top of REST to add eager-loading, and "eager-persisting". In
other words, we can both read and write a graph of data in a single
request:

[TODO IMAGE]

## Automation with Escape Valves / ORM Agnostic

ORM/DB, etcs

## (Micro) Services

> *You should think hard before breaking up [a Magestic Monolith](https://m.signalvnoise.com/the-majestic-monolith); beware the tradeoffs. Still, if you need it, Graphiti has your back.*

We now have a consistent interface for queries and relationships. We
also covered how Resources connect together with Links. Put two and
two together, and you'll see a Resource doesn't need to be local to same
application. We can have cross-API, remote Resources as well.

The popular GraphQL platform Apollo calls this [Schema Stitching](https://www.apollographql.com/docs/graphql-tools/schema-stitching.html):

<p align="center">
  <img width="50%" src="https://user-images.githubusercontent.com/55264/52920133-506a1e00-32d7-11e9-8986-23795dbedc2c.png" />
</p>

You won't need to write code like this in Graphiti. Because we have
conventions, we can automate this stuff. Just supply a URL:

{% highlight ruby %}
class EmployeeResource < ApplicationResource
  has_many :positions, remote: 'http://example.com/api/positions'
end
{% endhighlight %}

That's it. Everything works the same. We can fetch an `Employee` and her `Position`s in a single
request, add additional local *or* remote Resources to the request, and
Deep Query. If you use Vandal, you'll think it's all the same API.

Microservices 🎉!

### Domain-Driven Design

TODO

## Clients

You can use any HTTP client with Graphiti. If you're using JS, a simple
`fetch` will do.

But you may be looking for a more robust client, one that takes
advantage of Graphiti conventions. Look no further than
[Spraypaint]({{site.github.url}}/js/home), our
official client heavily inspired by ActiveRecord. Query your API the
same way you query your database:

{% highlight typescript %}
// All of this is chainable

let { data } = await Employee
  .where({ name: { prefix: "Jane" } })
  .order({ created_at: "desc" })
  .page(2).per(10)
  .select(['name', 'age'])
  .stat({ total: 'count' })
  .includes({ positions: 'department' })
  .all()

let record = data[0]
record.positions[0].department.name = 'Updated!'
await record.save({ with: { positions: 'department' } })
{% endhighlight %}

By relying on conventions we can move the URL, request, and response
under the hood, allowing you to focus on what matters - your domain.

## GraphQL Support

OK, let's come full circle. Let's say some of these conventions resonate
with you, but you'd still like a GraphQL server. I ***still*** think
Graphiti is your best bet, because Graphiti supports GraphQL.

Remember, we started with this long-hand RPC code:

{% highlight typescript %}
type CreateEmployeeInput {
  name: String
  age: Int
}

type CreateEmployeePayload {
  employee: Employee
}

type UpdateEmployeeInput {
  employeeId: ID!
  name: String
  age: Int
}

type UpdateEmployeePayload {
  employee: Employee
}

type DestroyEmployeeInput {
  id: ID!
}

type DestroyEmployeePayload {
  employee: Employee
}

type Employee {
  id: ID!
  name: String
}

createEmployee(input: CreateEmployeeInput!): CreateEmployeePayload
updateEmployee(input: UpdateEmployeeInput!): UpdateEmployeePayload
destroyEmployee(input: DestroyEmployeeInput!): DestroyEmployeePayload

employee(id: ID!): Employee
{% endhighlight %}

Graphiti does not need all this boilerplate. But
if we have the short-hand, that means **we can automatically generate
the long-hand**. We can introspect the Graphiti Resources, and use
[graphql-ruby](https://github.com/rmosolgo/graphql-ruby) to automatically generate GraphQL code.

That project is [graphiti-graphql](https://github.com/wadetandy/graphiti-graphql). While still more of an experiment at this stage, it's shaping up nicely. The main blockers are the conventions missing from any GraphQL API - how should we render validation errors, which sorting standard should we adopt, etc. But we have proof that if there's a target to hit, we can autogenerate it.

So we ***can*** generate GraphQL via Graphiti, but should we? Maybe! Not
an unreasonable pursuit. If you'd like to go down this route, I'd love
to hear from you!

Still, let's be clear what we're missing: HTTP caching, error codes, lazy-loading, and more.

## Magic

> *Having that level of consistency, and working with that for
> just a little while means that you can start to forget about it. And
> that's the power of conventions in general...it used to be something
> you had to think about and make a decision. Well, decisions are bad.
> Decisions take up your brain power, and it requires brain cycles to
> consider which or the other. The more decisions you can take out of
> the whole thing, the more brain power you can free up to consider the
> really important things.*
>
> *If everybody is doing the same thing in the same way, it means that
> you can easily go from one application to the other, and expect the
> same things to happen.*
>
> \- ["Resources on Rails"](https://www.youtube.com/watch?v=GFhoSMD6idk), David Heinemeier Hansson

When conventions form your programming foundation, you end up with these
high-level abstractions where a few lines of code hide the underlying
complexity. Often, this is flippantly referred to as ✨"**Magic**"🔮

The thing about magic is, once you learn the trick it often comes down
to something simple: a mirror, a trick deck, a quick hand.

An object, moving back and forth.

<p align="center">
  <img width="50%" src="https://user-images.githubusercontent.com/55264/52913247-36561e80-328a-11e9-98ea-5e743920d317.gif" />
</p>

Simple concepts can often be the most powerful, and I will never get
tired of seeing this trick performed.

There's plenty more we haven't even touched on. Check out the
[Guides], or dive right in with the [Quickstart] or [Tutorial]. If
things get tricky, ask for help in our [Slack Chat]. Reach out to me
directly at richmolj@gmail.com or @richmolj on Twitter.

Let's put on a show together.

<br />
<br />
<br />
