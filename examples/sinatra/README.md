# Graphiti on Sinatra

Graphiti serving HTTP without Rails: the same Resources as the plain-ruby example, exposed over JSON:API endpoints by a Sinatra app, with `rescue_registry` rendering not-found errors as JSON:API.

```bash
bundle install
bundle exec rackup
```

Then visit [http://localhost:9292](http://localhost:9292) for a small explorer page that fetches each endpoint live, or curl directly:

```bash
curl -g 'localhost:9292/api/v1/employees?filter[age][gt]=30&include=positions.department'
```

Run the smoke test (what CI runs):

```bash
bundle exec ruby smoke.rb
```

The Gemfile points at the gem source two directories up, so this always runs against the checkout you're in.
