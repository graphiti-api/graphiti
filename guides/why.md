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

{% highlight js %}
// https://blog.tylerbuchea.com/a-simple-graphql-example-with-relationships/
type Mutation {
  signup(organization:String, id:String, name:String): User
}

// more "restful"
type Mutation {
  addUserToGroup(input: AddUserToGroupInput): AddUserToGroupPayload
  removeUserFromGroup(input: AddUserToGroupInput): AddUserToGroupPayload
}
{% endhighlight %}

Can we do it with domain? Sure. But means choices, and often lock-in to
a specific library











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
