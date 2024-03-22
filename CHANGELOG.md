graphiti changelog

## [1.6.1](https://github.com/graphiti-api/graphiti/compare/v1.6.0...v1.6.1) (2024-03-22)


### Bug Fixes

* correct thread-pool mutex logic which was causing a deadlock ([0400ab0](https://github.com/graphiti-api/graphiti/commit/0400ab0d97a1382b66b5295fdc7aa7db680e77cc))

# [1.6.0](https://github.com/graphiti-api/graphiti/compare/v1.5.3...v1.6.0) (2024-03-20)


### Features

* add thread pool and concurrency_max_threads configuration option ([#470](https://github.com/graphiti-api/graphiti/issues/470)) ([697d761](https://github.com/graphiti-api/graphiti/commit/697d76172adec24cd7e7522300c8335233fdcc36))

## [1.5.3](https://github.com/graphiti-api/graphiti/compare/v1.5.2...v1.5.3) (2024-03-18)


### Bug Fixes

* leverage ruby-2.7 parameter forwarding ([#431](https://github.com/graphiti-api/graphiti/issues/431)) ([ae09a46](https://github.com/graphiti-api/graphiti/commit/ae09a464b2156742bb093537deac0578a1a3e40e))
* prevent :id stripping when :id not in path ([#447](https://github.com/graphiti-api/graphiti/issues/447)) ([e1dd811](https://github.com/graphiti-api/graphiti/commit/e1dd811283f6e6fe7a36b925934df0ecbb4d3411))

## [1.5.2](https://github.com/graphiti-api/graphiti/compare/v1.5.1...v1.5.2) (2024-03-18)


### Bug Fixes

* Enum should allow the conventionally case-sensitive operators ([#434](https://github.com/graphiti-api/graphiti/issues/434)) ([56d34fd](https://github.com/graphiti-api/graphiti/commit/56d34fd4801bc32c13d64aca880b82b717b2ab81))

## [1.5.1](https://github.com/graphiti-api/graphiti/compare/v1.5.0...v1.5.1) (2024-03-18)


### Bug Fixes

* polymorphic `on` expects a symbol ([#433](https://github.com/graphiti-api/graphiti/issues/433)) ([4e58702](https://github.com/graphiti-api/graphiti/commit/4e587021265323bd0b170b57e9c7aecaa7f826d7))

# [1.5.0](https://github.com/graphiti-api/graphiti/compare/v1.4.0...v1.5.0) (2024-03-18)


### Features

* add before_sideload hook ([#371](https://github.com/graphiti-api/graphiti/issues/371)) ([f68b61f](https://github.com/graphiti-api/graphiti/commit/f68b61ff09ec61ecf23acc5bc37d0accba14aeed))

## 1.4.0, Sun March 17th 2024
Features: 
- [461](https://github.com/graphiti-api/graphiti/pull/461), [463](https://github.com/graphiti-api/graphiti/pull/463) Add support for Rails 7.1 + Ruby 3.2 + Ruby 3.3

Fixes: 
- [464](https://github.com/graphiti-api/graphiti/pull/464) Check for url presence before trying to append
- [407](https://github.com/graphiti-api/graphiti/pull/407) Sort types in generated schema
- [421](https://github.com/graphiti-api/graphiti/pull/421) Re-use resource class for remote sideloads to avoid memory leak
- [452](https://github.com/graphiti-api/graphiti/pull/452) Resolve inconsistency for filters containing curly brackets
- [446](https://github.com/graphiti-api/graphiti/pull/446) Fix private call

## 1.3.9, May 25th 2022
Use an options hash for log subscriber instead of positional arguments

## 1.x ?? 

Features:
- [329](https://github.com/graphiti-api/graphiti/pull/329) Propagate `extra_fields` to related resource links.
- [242](https://github.com/graphiti-api/graphiti/pull/242) Bump `jsonapi-renderer` to `~0.2.2` now that (https://github.com/jsonapi-rb/jsonapi-renderer/pull/36) is fixed.
- [158](https://github.com/graphiti-api/graphiti/pull/158) Filters options `allow_nil: true`
  Option can be set at the resource level `Resource.filters_accept_nil_by_default = true`. 
  By default this is set to false. (@zeisler)
- [157](https://github.com/graphiti-api/graphiti/pull/157) Using attribute option schema: false.
  This option is default true and is not effected by only and except options. (@zeisler)

Fixes:
- [282] Support model names including "Resource"
- [313](https://github.com/graphiti-api/graphiti/pull/313) Sort remote resources in schema generation
- [374](https://github.com/graphiti-api/graphiti/pull/374) Trim leading spaces from error messages

## 1.1.0

Features:

- [#126](https://github.com/graphiti-api/graphiti/pull/126) Render helpful user-facing errors when a write payload is invalid (@wadetandy)

Fixes:

- [#136](https://github.com/graphiti-api/graphiti/pull/136) Fix remote
  belongs_to links (@richmolj)

Misc:

- [#123](https://github.com/graphiti-api/graphiti/pull/123) Throw
  better error when polymorphic type not found.

## 1.0.3

Fixes:

- [#130](https://github.com/graphiti-api/graphiti/pull/130) Run query
  blocks in resource context (@richmolj)

## 1.0.2

Fixes:

- [#125](https://github.com/graphiti-api/graphiti/pull/125) Fix destroy
  with validation errors (@mihaimuntenas)

## 1.0.1

Fixes:

- [#127](https://github.com/graphiti-api/graphiti/pull/127) Avoid Rails eager loading edge case with polymorphic resources (@richmolj)

### master (unreleased)

Features:

- [#153](https://github.com/graphiti-api/graphiti/pull/153) Add after_graph_persist hook.
  This hook fires after the graph of resources is persisted and before validation. (@A-Boudi)

<!-- ### [version (YYYY-MM-DD)](diff_link) -->
<!-- Breaking changes:-->
<!-- Features:-->
<!-- Fixes:-->
<!-- Misc:-->
