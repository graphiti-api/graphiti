---
title: 'OpenStruct Models'
---

# OpenStruct Models

[Model Requirements](/concepts/backends-and-models#model-requirements) covers what any Model needs to respond to, and [Usage Without ActiveRecord](/topics/without-activerecord) walks through building a Resource around a PORO. `OpenStruct` satisfies those requirements with zero boilerplate - no `attr_accessor` list, no constructor - which is exactly why Graphiti uses it internally for [remote resources](/topics/remote-resources): `Resource::Remote` and the default `Sideload` model both set `model OpenStruct` (`lib/graphiti/resource/remote.rb`, `lib/graphiti/sideload.rb`), since a remote resource doesn't know its shape ahead of time. That convenience comes with sharp edges if you reach for `OpenStruct` as a model in your own Resources.

## What Graphiti expects from it {#expectations}

Reads go through `@object.send(attribute_name)` (`lib/graphiti/util/serializer_attributes.rb`), and writes go through `model.send(:"#{key}=", value)`-style assignment. `OpenStruct` handles both via `method_missing`, so any attribute you construct it with - or assign later - just works, same as a PORO with `attr_accessor`.

## The gotcha: typos and reserved methods return silently, they don't raise {#gotcha}

An `attr_accessor`-based PORO raises `NoMethodError` the moment you call an undefined reader. `OpenStruct` does not - if the attribute was never set, `#send` on it just returns `nil`:

```ruby
require "ostruct"
o = OpenStruct.new(name: "a")
o.send(:naem)  # => nil, not NoMethodError
```

Since attribute reads happen inside `@object.send(name_ref)`, a typo'd attribute name (in your `attribute` declaration, or a rename you forgot to propagate) will silently serialize as `null` instead of blowing up in your test suite. With a real PORO the same typo raises immediately and is easy to catch.

Worse, `OpenStruct` only overrides *undefined* methods - if the attribute name collides with something `Object`/`Kernel` already defines, the field is silently swallowed and you get the *original* method's return value instead of your data:

```ruby
o = OpenStruct.new(hash: 123, count: 5)
o.hash   # => some large integer (Object#hash), NOT 123
o.count  # => 5, fine - `count` isn't a reserved method
```

`id`, `class`, `object_id`, `hash`, `send`, `freeze`, and `to_s` are all real methods on every Ruby object. Naming an attribute after one of them (a `hash` field to store a checksum is a realistic trap given Graphiti's own `:hash` type) won't error - it'll quietly return the wrong value. `id` itself is safe (`Object#id` was removed from modern Ruby in favor of `#object_id`), but don't assume the rest are.

## Validations {#validations}

`OpenStruct` doesn't include `ActiveModel::Validations`, and the [Null adapter's `#save`](/concepts/backends-and-models#model-requirements) only calls `model.valid?` if the model `respond_to?(:valid?)` - so an unvalidated `OpenStruct` model will save "successfully" with no errors payload, not raise. If you want write-request validation, subclass it:

```ruby
class Employee < OpenStruct
  include ActiveModel::Validations
  validates :first_name, presence: true
end
```

This works exactly as it would on any other class - `OpenStruct` doesn't get in the way of `include`.

## When it's the right call {#when}

`OpenStruct` is a reasonable choice for throwaway resources, prototypes, and cases like remote resources where the attribute set is genuinely dynamic. For a Resource you're going to maintain, prefer a real PORO, `ActiveModel::Model`, or `Dry::Struct` (all shown in [Model Implementations](/concepts/backends-and-models#model-implementations)) - you get the same zero-ORM flexibility with a class that fails loudly on a mistake instead of quietly serializing `nil`.
