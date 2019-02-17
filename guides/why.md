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

Many GraphQL posts define REST like so:

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
> *Lets consider this:*
>
> *Marcus is a farmer. He has a ranch with 4 pigs, 12 chickens and 3 cows. He is now simulating a REST api while i am the client. If i want to request the current state of his farm using REST i just ask him: "State?"*
>
> *Marcus answers: "4 pigs, 12 chickens, 3 cows".
This is the most simple example of Representional State Transfer. Marcus transfered the state of his farm to me using a representation. The representation of the farm is the plain sentence: "4 pigs, 12 chickens, 3 cows".*
>
> *So lets get to the next level. How would i tell Marcus to add 2 cows to his farm the REST way?
Maybe tell him: "Marcus, please add 2 cows to your farm".*
>
> *Do you think this was REST? Are we transfering state by its representation here? NO! This was calling a remote procedure. The procedure of adding 2 cows to the farm.*
>
> *Marcus sadly answers: "400, Bad Request. What do you mean?"*
>
> *So lets try this again. How would we do this the REST way? What was the representation again? It was "4 pigs, 12 chickens, 3 cows". Ok. so lets try this again transfering the representation...*
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

The first things to note is that GraphQL is super badass at describing
fields and types. The next thing to note is that fields and types are
the wrong abstraction.

Defining a schema like this allows bespoke, fine-grained detail. If we
wanted, the `CreateEmployeePayload` could be different than the
`UpdateEmployeePayload` - same for inputs like `CreateEmployeeInput` and
`UpdateEmployeeInput`. If we wanted other actions, like
`promoteEmployee` or `deactivateEmployee`, they would be easy to add and
follow the same basic constructs.

This is RPC - hand-crafted, custom requests. We have a high level of
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

Getting there. OK and we know we're dealing with an Employee, and we
know we won't have custom verbs like `promote` or `remove`.

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

What about sorting? Should we do it similar to the Github API?:

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
but it makes a reasonable baseline to query a Resource by its
attributes.

If we have an attribute and it's a `string`, we know we're
talking about operators like `suffix` and `prefix`, but an `integer`
attribute would want operators like `greater_than` and `less_than`.

OK, so really we don't need to define *inputs* and *outputs* - those can
be assumed by convention. What we really need to define is the Resource.

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
websites, websites have forms, so what if we:

<br />

<p align="center">
  <img width="30%" src="https://user-images.githubusercontent.com/55264/52916024-e3d82a80-32a8-11e9-8bb6-07ac9bf988dc.png" />
</p>

<br />

This screenshot is from [Vandal](https://graphiti-api.github.io/graphiti/guides/vandal), the Graphiti UI.

Because we started with a better abstraction, we ended with a better
visualization. As a marketer-turned-programmer myself, I really
appreciate when data exploration tools like this are friendly to
less-technical users. I like that my product owner and I can walk
through the domain together, validating concepts and solidifying a shared
understanding. A user of Vandal doesn't need to know about `Connection`s
or `Edge`s, they just need to click around.

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
informed but changing this default could raise a backwards-compatibility
error:

{% highlight bash %}
EmployeeResource: default sort changed from [{:created_at=>"desc"}] to [{:last_name=>"asc"}].
{% endhighlight %}


Relationships at some point?
schema stitching.







* backwards compat sort




then schema stiching












https://twitter.com/sarahmei/status/702281663896653824






Why do we have to spell
this out each time? This can lead to subtle inconsistencies, both within
this project and across other projects.
* Same for the input.
* 


















changeUserStatus(input: ChangeUserStatusInput!): ChangeUserStatusPayload

addPullRequestReview(input: AddPullRequestReviewInput!): AddPullRequestReviewPayload

submitPullRequestReview(input: SubmitPullRequestReviewInput!): SubmitPullRequestReviewPayload

deletePullRequestReview(input: DeletePullRequestReviewInput!): DeletePullRequestReviewPayload










Those objects are connected, and together those connections form a
**graph**. REST allows you to lazy-load that graph using URL links:

In other words, **REST is optimized for lazy-loading**. REST is great at A) supplying conventions that will lead to cleaner object-oriented code B) lazy-loading data C) caching.

REST is incredibly powerful, well-understood, and well-supported. We
don't need to get rid of REST. We need to add **eager loading**:

[TODO EAGER]





> 19:35 *Having that level of consistency, and working with that for
> just a little while means that you can start to forget about it. And
> that's the power of conventions in general...it used to be something
> you had to think about and make a decision. Well, decisions are bad.
> Decisions take up your brain power, and it requires brain cycles to
> consider which or the other. The more decisions you can take out of
> the whole thing, the more brain power you can free up to consider the
> really important things.

> If everybody is doing the same thing in the same way, it means that
> you can easily go from one application to the other, and expect the
> same things to happen.
>
> \- ["Resources on Rails"](https://www.youtube.com/watch?v=GFhoSMD6idk), David Heinemeier Hansson












This first, on simplicity and conventions:

There is simply no need for this:

* submit, add, unlock
* the input is a `PullRequestReview`
* the output is a `PullRequestReview`

submitPullRequestReview(input: SubmitPullRequestReviewInput!): SubmitPullRequestReviewPayload


REST would say: just tell me about your Pull Request. I already know how
to CRUD it, so just tell me what it is.

Edges and Connections


class PullRequestResource
end

* Create read update delete

add

has_many :comments

CRUD comments, disassociate

Let's see what else we can do.

Because resource with attributes, and attributes have types, we can
infer filters - prefix and suffix, greater than less than.


Our schema doesn't need to define inputs and outputs - REST already
tells us what those are. So, what we need to define are Resources,
marking attributes writable readable etc


Because query interface, schema stitching.


Just as REST gives us constraints, for saving, thinking about resources
gives us contraints for querying. Resources have attributes, and we'll
want to filter and sort on those attributes. We'll need to paginate, and
maybe add statistics. That's it.


show it all, and say all this was possible because we started with a
simple concept, one that's been around forever and powers much of the
web today. When solving problems, we should build on existing solutions
and embrase positive-sum thinking.




When we add conventions, great things happen. That doesn't mean
conventions are "what works with activerecord" - conventions must be
informed by diverse opinions and perspectives. But still, arriving at
one way to do things is the sweet spot.





Core value: Common conventions informed by diverse perspectives
