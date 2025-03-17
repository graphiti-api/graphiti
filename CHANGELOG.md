graphiti changelog

## [1.8.1](https://github.com/graphiti-api/graphiti/compare/v1.8.0...v1.8.1) (2025-03-17)

# [1.8.0](https://github.com/graphiti-api/graphiti/compare/v1.7.9...v1.8.0) (2025-03-17)


### Features

* add thread pool with promises to limit concurrent sideloading ([#472](https://github.com/graphiti-api/graphiti/issues/472)) ([2998852](https://github.com/graphiti-api/graphiti/commit/2998852cea3e5f366e3748d808e26e83e484e989))

## [1.7.9](https://github.com/graphiti-api/graphiti/compare/v1.7.8...v1.7.9) (2025-03-16)


### Bug Fixes

* update version check for clear active connections active record deprecation ([#491](https://github.com/graphiti-api/graphiti/issues/491)) ([4e764f6](https://github.com/graphiti-api/graphiti/commit/4e764f66c3a06b4a83c37afa83ddd64a78ef3b19))

## [1.7.8](https://github.com/graphiti-api/graphiti/compare/v1.7.7...v1.7.8) (2025-03-16)


### Bug Fixes

* compare URI-decoded path params ([#482](https://github.com/graphiti-api/graphiti/issues/482)) ([20b80dd](https://github.com/graphiti-api/graphiti/commit/20b80dd35bfa4e2f677af3fb9472def6da668149))
* correct issue with many_to_many when one of the models has a prefix to the intersection model association ([#449](https://github.com/graphiti-api/graphiti/issues/449)) ([dc28a4f](https://github.com/graphiti-api/graphiti/commit/dc28a4f72fe4c577e23ced102a0b5e7063ba8026))
* lazy constantize relation resources ([#492](https://github.com/graphiti-api/graphiti/issues/492)) ([3cc2983](https://github.com/graphiti-api/graphiti/commit/3cc298399b4dc8970a2beed49b333396c76bd218))

## [1.7.7](https://github.com/graphiti-api/graphiti/compare/v1.7.6...v1.7.7) (2025-03-15)


### Bug Fixes

* change class attribute behavior on endpoint method to work in ruby 3.2+ ([#493](https://github.com/graphiti-api/graphiti/issues/493)) ([04f1f3c](https://github.com/graphiti-api/graphiti/commit/04f1f3c783bfe18e6568cc21924d417a82234135))

## [1.7.6](https://github.com/graphiti-api/graphiti/compare/v1.7.5...v1.7.6) (2024-11-06)


### Bug Fixes

* Gem version check ([#483](https://github.com/graphiti-api/graphiti/issues/483)) ([68e2492](https://github.com/graphiti-api/graphiti/commit/68e2492032692d8bb928a733f8b0f8710be31c49))

## [1.7.5](https://github.com/graphiti-api/graphiti/compare/v1.7.4...v1.7.5) (2024-09-16)


### Bug Fixes

* Fixes error in version check for ActiveRecord adapter introduced in [#478](https://github.com/graphiti-api/graphiti/issues/478) ([#479](https://github.com/graphiti-api/graphiti/issues/479)) ([42c82c3](https://github.com/graphiti-api/graphiti/commit/42c82c397f20eb91c02835e518ff4c351c028ea7))

## [1.7.4](https://github.com/graphiti-api/graphiti/compare/v1.7.3...v1.7.4) (2024-09-11)


### Bug Fixes

* update ActiveRecord adapter w/ support for Rails 7.2+ ([#478](https://github.com/graphiti-api/graphiti/issues/478)) ([8313e33](https://github.com/graphiti-api/graphiti/commit/8313e3359f0dde28d9940867c7ded964db4c854d))

## [1.7.3](https://github.com/graphiti-api/graphiti/compare/v1.7.2...v1.7.3) (2024-06-26)


### Bug Fixes

* require OpenStruct explicitly ([#475](https://github.com/graphiti-api/graphiti/issues/475)) ([e0fa18a](https://github.com/graphiti-api/graphiti/commit/e0fa18a8d7f051e385e6e081f79f2ecae92a9260))

## [1.7.2](https://github.com/graphiti-api/graphiti/compare/v1.7.1...v1.7.2) (2024-06-11)


### Bug Fixes

* require necessary ActiveSupport parts in proper order ([bb2a488](https://github.com/graphiti-api/graphiti/commit/bb2a48874a6533522df6eb027d0df8ec14c80a20))

## [1.7.1](https://github.com/graphiti-api/graphiti/compare/v1.7.0...v1.7.1) (2024-04-18)


### Bug Fixes

* properly display .find vs .all in debugger statements ([d2a7a03](https://github.com/graphiti-api/graphiti/commit/d2a7a038a649818979d52ccd898e68dba78b051f))
* rescue error from sideloads updated_at calculation, defaulting to the current time ([661e3b5](https://github.com/graphiti-api/graphiti/commit/661e3b5212e2649870a200067d0d5d52fa962637))

# [1.7.0](https://github.com/graphiti-api/graphiti/compare/v1.6.4...v1.7.0) (2024-03-27)


### Features

* Add support for caching renders in Graphiti, and better support using etags and stale? in the controller ([#424](https://github.com/graphiti-api/graphiti/issues/424)) ([8bae50a](https://github.com/graphiti-api/graphiti/commit/8bae50ab82559e2644d506e16a4f715effd89317))

## [1.6.4](https://github.com/graphiti-api/graphiti/compare/v1.6.3...v1.6.4) (2024-03-27)

## [1.6.3](https://github.com/graphiti-api/graphiti/compare/v1.6.2...v1.6.3) (2024-03-26)


### Bug Fixes

* Remove thread pool executor logic until we get a better handle on what's causing thread pool hangs. refs [#469](https://github.com/graphiti-api/graphiti/issues/469) ([7941b6f](https://github.com/graphiti-api/graphiti/commit/7941b6f75ce1001b034ed6e83c148b893e9f3d99)), closes [#471](https://github.com/graphiti-api/graphiti/issues/471) [#470](https://github.com/graphiti-api/graphiti/issues/470)

## [1.6.2](https://github.com/graphiti-api/graphiti/compare/v1.6.1...v1.6.2) (2024-03-22)


### Bug Fixes

* thread pool scope and mutex need to be global across all instances of Scope for it to be a global thread pool ([#471](https://github.com/graphiti-api/graphiti/issues/471)) ([51fb51c](https://github.com/graphiti-api/graphiti/commit/51fb51c31f0043d98aa07f689a8cf8c758fa823b))

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
