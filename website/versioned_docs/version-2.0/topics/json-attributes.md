---
title: 'JSON Attributes'
---

# JSON Attributes

Graphiti has two built-in types for structured data: `hash` and `array`. Both are useful for serving JSON/JSONB columns (or any nested data) through a Resource, without you writing custom typecasting.

For the full type table, see [Types](/concepts/resources#types). This page covers `hash` and `array` specifically.

## Declaring the attribute {#declaring}

```ruby
class PostResource < ApplicationResource
  attribute :metadata, :hash
  attribute :tags, :array
end
```

Like any attribute, this is readable, writable, sortable and filterable by default. If your model reads a `metadata` JSONB column and returns a Ruby `Hash`, `attribute :metadata, :hash` will render it as-is.

## Coercion rules {#coercion}

Each type is a [Dry::Types](https://dry-rb.org/gems/dry-types) triple of `params` (used for filtering/sorting from query strings), `read`, and `write`. Per `lib/graphiti/types.rb`:

* `hash` - `read` and `write` are `Dry::Types["strict.hash"]`. Nothing is coerced beyond requiring a real `Hash`. `params` is a custom type that runs `JSON.parse(input) if input.is_a?(String)` before validating with `Dry::Types["params.hash"]`, so a JSON string arriving in a query param gets parsed automatically.
* `array` - `read`, `write`, and `params` are all `Dry::Types["strict.array"]`. There is no `.of(...)` constraint, so elements are not individually coerced. Any array (including an array of hashes) passes through as-is.

Both types have `kind: "record"` (`hash`) or `kind: "array"` (`array`) rather than `"scalar"`. One consequence: unlike every other base type (`integer`, `string`, `date`, etc.), `hash` and `array` do **not** get an `array_of_*` doppelgänger generated (`lib/graphiti/types.rb` explicitly excludes `:boolean`, `:hash`, and `:array` when building `array_of_*` variants). If you need an array of hashes, just use `attribute :things, :array` - there's no `array_of_hashes` type.

On coercion failure - reading, writing, or filtering - Graphiti raises `Graphiti::Errors::TypecastFailed` with the attribute name, the offending value, and the underlying error.

## Filtering on a hash attribute {#filtering}

Declaring `attribute :metadata, :hash` makes it filterable with the `eq` operator by default (the `hash` type only supports `eq` out of the box, per the default operator map). A request like:

```
GET /posts?filter[metadata]={"status":"draft"}
```

parses the JSON string into a Ruby `Hash` before your filter block runs:

```ruby
filter :metadata, :hash do
  eq do |scope, value|
    # value => [{ "status" => "draft" }]
    scope
  end
end
```

Note the value is wrapped in an array - Graphiti's filter pipeline supports passing multiple comma-separated JSON objects (`filter[metadata]={"a":1},{"b":2}`), so `eq` always receives an array of hashes unless you opt out.

Pass `single: true` to receive the hash directly instead of an array-wrapped one, and to skip the comma-splitting behavior entirely (useful once your hash values might legitimately contain commas):

```ruby
filter :metadata, :hash, single: true do
  eq do |scope, value|
    # value => { "status" => "draft" }
    scope
  end
end
```

A Ruby `Hash` (rather than a JSON string) passed directly as a filter param works the same way. It's validated rather than parsed.

Array attributes filter similarly: `filter[tags]=ruby,rails` splits on commas into `["ruby", "rails"]`. Wrap a value in `{{curlies}}` to prevent comma-splitting (see [Escaping Values](/concepts/resources#escaping-values)).

## Writing to a JSON column {#writing}

There's nothing Graphiti-specific to do here. On a write request, Graphiti coerces the incoming JSON attribute through the `write` type (`strict.hash` or `strict.array` - just a presence/type check) and assigns it to your model via `attributes[:metadata] = value`. Persisting that Ruby `Hash`/`Array` into an actual `jsonb`/`json` column is entirely up to your ORM (ActiveRecord serializes it automatically for `jsonb`/`json` columns) - Graphiti does not serialize to a JSON string itself, so don't do that in your own code either or you'll end up double-encoded.

## Caveats {#caveats}

* `hash` and `array` only support the `eq` filter operator by default - there's no built-in `gt`/`lt`/`prefix` for structured data. Add custom operators yourself if you need them.
* Non-`single` hash filters always hand your `eq` block an array, even for a single JSON object - a common source of confusion is forgetting the `value[0]` unwrap.
* There's no schema validation built in - `strict.hash`/`strict.array` just confirm you got a `Hash`/`Array`, not that its keys match anything in particular. For a shape check, register a [custom type](/concepts/resources#custom-types) with `Dry::Types["hash"].schema(...)`.
