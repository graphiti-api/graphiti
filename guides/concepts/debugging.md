---
layout: page
---

<div markdown="1" class="toc col-md-3">
Debugging
==========

* 1 [Debugger](#debugger)
  * [JSON Output](#json-output)
  * [Configuration](#configuration)
* 2 [Rake Tasks](#rake-tasks)
  * [graphiti:request](#graphitirequest)
  * [graphiti:benchmark](#graphitibenchmark)
* 3 [Tips](#tips)

</div>

<div markdown="1" class="col-md-8">
## 1 Debugger

Graphiti comes with a debugger that shows the queries executed for a
given request. Remember that Resources [have a query interface]({{site.github.url}}/guides/concepts/resources#query-interface) independent of a request or response. And Resources connect similar to ActiveRecord's `includes`:

{% highlight ruby %}
employees = EmployeeResource.all
PositionResource.all(filter: { employee_id: employees.map(&:id) })
{% endhighlight %}

> *Remember, this is all [customizable]({{site.github.url}}/guides/concepts/resources#customizing-relationships)*.

That means we can log the requests made by individual Resources:

`/api/v1/employees?include=notes,positions.department.teams`
<p align="center">
  <img width="100%" src="https://user-images.githubusercontent.com/55264/46084994-f5425e00-c172-11e8-8c40-aa7074e6dc6d.png">
</p>

And even copy/paste these queries into a console session to debug:

{% highlight bash %}
$ bin/rails c
>> TeamResource.all({:filter=>{:department_id=>"1,2,3"}})
{% endhighlight %}

If you're having trouble with a request, see if you can isolate to a
specific Resource, then test that Resource directly.

Finally: if an error occurs, we'll note the query that caused it:

<p align="center">
  <img width="100%" src="https://user-images.githubusercontent.com/55264/46086595-6c2d2600-c176-11e8-9b57-1b27d380e9fe.png">
</p>

### 1.1 JSON Output

It can be helpful to have this debug output come back as part of the
JSON response. To enable this:

{% highlight ruby %}
# app/controllers/application_controller.rb
def allow_graphiti_debug_json?
  true
  # or, current_user.admin?
  # or, Rails.env.development?
end
{% endhighlight %}

And request the debug output:

`/your/url?debug=true`

You should now see the debug output in `meta`:

<p align="center">
  <img width="100%" src="https://user-images.githubusercontent.com/55264/46085006-fe332f80-c172-11e8-946e-bf1386362a90.png">
</p>

<br />

If there's an error, and you've [enabled raw errors]({{site.github.url}}/guides/concepts/error-handling#displaying-raw-errors), you'll also see the query that caused the error in the JSON response:

<br />

<p align="center">
  <img width="100%" src="https://user-images.githubusercontent.com/55264/46086370-ef01b100-c175-11e8-81b9-917d95e195c7.png">
</p>

<br />

### 1.2 Configuration

By default, we'll log to `Rails.logger`, and only enable debugging (logs
or JSON) when `Rails.logger.level` is set to `debug`. Here are the
various ways to configure.

Use `config.debug` to explicitly toggle debugging:

{% highlight ruby %}
# config/initializers/graphiti.rb
Graphiti.configure do |c|
  c.debug = false
end

# Or use environment variable
# GRAPHITI_DEBUG=false
{% endhighlight %}

Use `config.debug_models` to get additional (but verbose) output:

<p align="center">
  <img width="100%" src="https://user-images.githubusercontent.com/55264/46088701-ef507b00-c17a-11e8-8d26-af17b19b8ce9.png">
</p>

{% highlight ruby %}
# config/initializers/graphiti.rb
Graphiti.configure do |c|
  c.debug_models = true
end

# Or use environment variable
# GRAPHITI_DEBUG_MODELS=true
{% endhighlight %}

As noted above, `allow_graphiti_debug_json?` must return `true` if you
want JSON output:

{% highlight ruby %}
# app/controllers/application_controller.rb
def allow_graphiti_debug_json?
  true
  # or, current_user.admin?
  # or, Rails.env.development?
end
{% endhighlight %}

Note you need to explicitly pass `?debug=true` in the request.

Assign a different logger:

{% highlight ruby %}
Graphiti.logger = Logger.new(...)

# Or the built-in STDOUT logger:
Graphiti.logger = Graphiti.stdout_logger
{% endhighlight %}

Manually apply the debugging (when using Rails, this normally happens in
a `around_action`):

{% highlight ruby %}
Graphiti::Debugger.debug do
  EmployeeResource.all
end
{% endhighlight %}

### 2 Rake Tasks

There are some common debugging scenarios that are possible to do
manually, but their frequency warrants common patterns. For these, we
have rake tasks.

#### 2.1 graphiti:request

> `bin/rake graphiti:request[PATH,DEBUG]`

Execute a request using `ActionDispatch::Integration::Session` (which
underlies request specs).

This can be helpful when you don't have, or don't want to spin up, a web
server. Imagine you want to debug something on production, so you shell
into a docker container and edit some files locally. Now you want to
execute a request and see if your changes worked:

{% highlight bash %}
$ bin/rake graphiti:request[/employees]
{% endhighlight %}

Will execute the request and spit out the JSON response. You may want to
run with the Debugger enabled:

{% highlight bash %}
$ bin/rake graphiti:request[/employees,true]
{% endhighlight %}

Which add Debugger output as well.

The `PATH` should not contain the domain unless you want to hit a live
API instead of a test server.

#### 2.2 graphiti:benchmark

> `bin/rake graphiti:benchmark[PATH,NUM_REQUESTS]`

It can be helpful to run a quick benchmark without hitting a live web
server, to eliminate the vagaries of latency. To do this:

{% highlight bash %}
$ bin/rake graphiti:benchmark[/employees,100]
{% endhighlight %}

Which will return the average response time.

## 3 Tips

When debugging an application, try to isolate the individual Resource
call and debug the Resource directly (instead of running the entire
request). This helps eliminate variables, and plain ruby code is easier
to work with. If possible, try to remove Graphiti entirely and focus on
your Models and Backends.

The most common scenario is debugging a query. We suggest overriding
`resolve` and using [pry](https://github.com/pry/pry) (or equivalent):

{% highlight ruby %}
# Introspect the scope without firing a query
# Call 'super' to fire the query
def resolve(scope)
  binding.pry
end
{% endhighlight %}

<br />
<br />

</div>
