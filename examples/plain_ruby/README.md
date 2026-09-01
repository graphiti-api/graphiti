# Graphiti in a plain .rb file

Graphiti with nothing but Ruby: an in-memory sqlite database, three Resources, and one script that queries with filtering, sorting, pagination and nested sideloads, then renders JSON:API, plain JSON and XML.

```bash
bundle install
bundle exec ruby index.rb
```

The Gemfile points at the gem source two directories up, so this always runs against the checkout you're in.
