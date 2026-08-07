---
title: 'Debugging'
---

## Debugger {#debugger}

Graphiti comes with a debugger that shows the queries executed for a
given request. Remember that Resources [have a query interface](/concepts/resources#query-interface) independent of a request or response. And Resources connect similar to ActiveRecord's `includes`:

```ruby
employees = EmployeeResource.all
PositionResource.all(filter: { employee_id: employees.map(&:id) })
```

> *Remember, this is all [customizable](/concepts/relationships#customizing-relationships)*.

That means we can log the requests made by individual Resources:

`/api/v1/employees?include=notes,positions.department.teams`
<p align="center">
  <img width="100%" src="/assets/img/legacy/legacy-a2cc4363c3.png" />
</p>

And even copy/paste these queries into a console session to debug:

```bash
$ bin/rails c
>> TeamResource.all({:filter=>{:department_id=>"1,2,3"}})
```

If you're having trouble with a request, see if you can isolate to a
specific Resource, then test that Resource directly.

Finally: if an error occurs, we'll note the query that caused it:

<p align="center">
  <img width="100%" src="/assets/img/legacy/legacy-05bbd3e5fd.png" />
</p>

### JSON Output {#json-output}

It can be helpful to have this debug output come back as part of the
JSON response. To enable this:

```ruby
# app/controllers/application_controller.rb
def allow_graphiti_debug_json?
  true
  # or, current_user.admin?
  # or, Rails.env.development?
end
```

And request the debug output:

`/your/url?debug=true`

You should now see the debug output in `meta`:

<p align="center">
  <img width="100%" src="/assets/img/legacy/legacy-7f6889bc89.png" />
</p>

<br />

If there's an error, and you've [enabled raw errors](/topics/error-handling#displaying-raw-errors), you'll also see the query that caused the error in the JSON response:

<br />

<p align="center">
  <img width="100%" src="/assets/img/legacy/legacy-f67cfa89ab.png" />
</p>

<br />

### Configuration {#configuration}

By default, we'll log to `Rails.logger`, and only enable debugging (logs or JSON) when `Rails.logger.level` is set to `debug`. Here are the
various ways to configure.

Use `config.debug` to explicitly toggle debugging:

```ruby
# config/initializers/graphiti.rb
Graphiti.configure do |c|
  c.debug = false
end

# Or use environment variable
# GRAPHITI_DEBUG=false
```

Use `config.debug_models` to get additional (but verbose) output:

<p align="center">
  <img width="100%" src="/assets/img/legacy/legacy-3076df6209.png" />
</p>

```ruby
# config/initializers/graphiti.rb
Graphiti.configure do |c|
  c.debug_models = true
end

# Or use environment variable
# GRAPHITI_DEBUG_MODELS=true
```

As noted above, `allow_graphiti_debug_json?` must return `true` if you
want JSON output:

```ruby
# app/controllers/application_controller.rb
def allow_graphiti_debug_json?
  true
  # or, current_user.admin?
  # or, Rails.env.development?
end
```

Note you need to explicitly pass `?debug=true` in the request.

Assign a different logger:

```ruby
Graphiti.logger = Logger.new(...)

# Or the built-in STDOUT logger:
Graphiti.logger = Graphiti.stdout_logger
```

Manually apply the debugging (when using Rails, this normally happens in
a `around_action`):

```ruby
Graphiti::Debugger.debug do
  EmployeeResource.all
end
```

### Rake Tasks {#rake-tasks}

There are some common debugging scenarios that are possible to do
manually, but their frequency warrants common patterns. For these, we
have rake tasks.

#### graphiti:request {#graphiti-request}

> `bin/rake graphiti:request[PATH,DEBUG]`

Execute a request using `ActionDispatch::Integration::Session` (which
underlies request specs).

This can be helpful when you don't have, or don't want to spin up, a web
server. Imagine you want to debug something on production, so you shell
into a docker container and edit some files locally. Now you want to
execute a request and see if your changes worked:

```bash
$ bin/rake graphiti:request[/employees]
```

Will execute the request and spit out the JSON response. You may want to
run with the Debugger enabled:

```bash
$ bin/rake graphiti:request[/employees,true]
```

Which add Debugger output as well.

The `PATH` should not contain the domain unless you want to hit a live
API instead of a test server.

#### graphiti:benchmark {#graphiti-benchmark}

> `bin/rake graphiti:benchmark[PATH,NUM_REQUESTS]`

It can be helpful to run a quick benchmark without hitting a live web
server, to eliminate the vagaries of latency. To do this:

```bash
$ bin/rake graphiti:benchmark[/employees,100]
```

Which will return the average response time.

#### Authorization headers {#Authorization-headers}

If you have an Authorization scheme implemented (for example [authenticate_or_request_with_http_token](https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Token.html) in rails) you can supply the `Authorization` http header value with the `AUTHORIZATION_HEADER` environment variable:

```bash
$ export AUTHORIZATION_HEADER="Token --PRIVATE_API_KEY--"
$ bin/rake graphiti:request[/employees,true]
```

This also will work for `Basic` ([request_http_basic_authentication](https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Basic.html$$)) and `Bearer` values

## Tips {#tips}

When debugging an application, try to isolate the individual Resource
call and debug the Resource directly (instead of running the entire
request). This helps eliminate variables, and plain ruby code is easier
to work with. If possible, try to remove Graphiti entirely and focus on
your Models and Backends.

The most common scenario is debugging a query. We suggest overriding
`resolve` and using [pry](https://github.com/pry/pry) (or equivalent):

```ruby
# Introspect the scope without firing a query
# Call 'super' to fire the query
def resolve(scope)
  binding.pry
end
```
