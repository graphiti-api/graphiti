---
title: 'Step 0'
---

## Step 0: Bootstrapping

> [View the Code](https://github.com/graphiti-api/employee_directory/commit/e2552ce212c68b41a3eb8161deb822fff3e159d6)

Let's start by creating a new Rails project. For help with an existing
project, check out [Installation: From
Scratch](/getting-started/installation).

We'll use the `-m` option to install from a template, which will add a few gems and apply some setup boilerplate. Accept all the default options.

```bash
$ rails new employee_directory --api -m https://raw.githubusercontent.com/graphiti-api/graphiti_rails_template/master/all.rb
$ cd employee_directory
```

> Note: if a network issue prevents you from pointing to this URL directly, you can download the file and and run this command as `-m /path/to/template`

Feel free to run `git diff` to see what the generator did, otherwise commit the result. You can now head to [Step 1: Basic Resource](/tutorial/step_1), or continue reading to better understand the code.

#### Digging Deeper 🧐

You'll see some boilerplate in `config/routes.rb`:

```ruby
scope path: "/api/v1", defaults: {format: :jsonapi} do
  # your routes go here
end
```

This tells Rails that our API routes will be be prefixed - `/api/v1` by default. It also says that if no extension is in the URL (`.json`, `.xml`, etc), default
to the [JSONAPI Specification](http://jsonapi.org).

Let's look at the above `ApplicationResource`:

```ruby
class ApplicationResource < Graphiti::Resource
  abstract_class

  # We'll be using ActiveRecord
  adapter :active_record

  # Links are generated from base_url + endpoint_namespace
  base_url ENV.fetch('BASE_URL', 'http://localhost:3000')
  endpoint_namespace '/api/v1'
end
```

This should be pretty self-explanatory except for

```ruby
base_url ENV.fetch('BASE_URL', 'http://localhost:3000')
```

When deriving and validating [Links](/concepts/links), we'll use the `BASE_URL` variable if
present, falling back to the Rails development default of
`http://localhost:3000`. Unlike a Rails URL helper this needs the scheme and port, because it is the whole prefix every link is built on. This means our Links will look like:

```ruby
"#{ENV['BASE_URL']}/#{Resource.endpoint_namespace}/#{Resource.type}"
```

For example:

```ruby
http://my-website.com/api/v1/employees
```

Read more in the [Links Guide](/concepts/links).

Finally, there's some boilerplate in `ApplicationController`:

```ruby
class ApplicationController < ActionController::API
  include Graphiti::Rails::Controller
end
```

This wires Graphiti into the request cycle: the Graphiti context, the debugger, JSON:API error rendering, and `respond_to` (which `ActionController::API` normally strips out). Controllers render with `render jsonapi:`, and to render simple nested JSON like default Rails, we'll only need to add `.json` to the URL. (Prefer writing `respond_with(posts)`? The optional [responders integration](/getting-started/installation#responders) is one gem and one include away.)

That's it for basic setup!


  <h2 id="next">
    <a href="/tutorial/step_1">
      NEXT - 
      <small>Step 1: Basic Resource</small>
      &raquo;
    </a>
  </h2>
