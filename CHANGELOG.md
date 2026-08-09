graphiti changelog

# [2.0.0-beta.6](https://github.com/graphiti-api/graphiti/compare/v2.0.0-beta.5...v2.0.0-beta.6) (2026-08-09)


### Bug Fixes

* reject invalid page parameters ([#537](https://github.com/graphiti-api/graphiti/issues/537)) ([bb3698b](https://github.com/graphiti-api/graphiti/commit/bb3698b52911c658c5d023ad8fd55b5106195001)), closes [#347](https://github.com/graphiti-api/graphiti/issues/347)
* treat empty polymorphic configuration as unset ([#538](https://github.com/graphiti-api/graphiti/issues/538)) ([5c17899](https://github.com/graphiti-api/graphiti/commit/5c1789993fbb4638d4443cf014b8bef358addb80)), closes [#199](https://github.com/graphiti-api/graphiti/issues/199)


### Features

* Add graphiti:audit task to audit resources for issues ([84436ea](https://github.com/graphiti-api/graphiti/commit/84436eab7c7d0713ec6f355b62ba8b06913ee31a))
* raise MissingRelationshipMethod when rendering reads an association the model does not define ([1c41cee](https://github.com/graphiti-api/graphiti/commit/1c41cee787b4f747d2906b2230f8fb926e3d887d))
* rename always_include_resource_ids to resource_ids, with a belongs_to_resource_ids_by_default setting ([8b11151](https://github.com/graphiti-api/graphiti/commit/8b111516822f6fc6e3675b59941688791cb34e74))

# [2.0.0-beta.5](https://github.com/graphiti-api/graphiti/compare/v2.0.0-beta.4...v2.0.0-beta.5) (2026-08-07)


### Bug Fixes

* drop the relationship guard install notice ([c204312](https://github.com/graphiti-api/graphiti/commit/c20431214e126cb8e72c82022ee4c852b10a024b))
* keep rake task helpers out of the global namespace ([0a41a60](https://github.com/graphiti-api/graphiti/commit/0a41a6022fa4c9151948714c31db367aee330e22)), closes [graphiti-api/graphiti-rails#91](https://github.com/graphiti-api/graphiti-rails/issues/91)


### Features

* add rspec matchers for resource relationships and attributes ([70525f7](https://github.com/graphiti-api/graphiti/commit/70525f7e10c511aa0c867ecc873f63f1790b8247)), closes [graphiti-api/graphiti_spec_helpers#14](https://github.com/graphiti-api/graphiti_spec_helpers/issues/14)
* let the resource generator name the controller ([6ea7141](https://github.com/graphiti-api/graphiti/commit/6ea714181f3da011cae9f42477b4c3681a7a90ff)), closes [graphiti-api/graphiti-rails#53](https://github.com/graphiti-api/graphiti-rails/issues/53)

# [2.0.0-beta.4](https://github.com/graphiti-api/graphiti/compare/v2.0.0-beta.3...v2.0.0-beta.4) (2026-08-07)


### Bug Fixes

* a subclass redeclaring a relationship reaches its serializer ([976dbc4](https://github.com/graphiti-api/graphiti/commit/976dbc47e7bbf951da925a13a34f1bc9679470f8))
* make each appraisal test the Rails version it is named for ([9e00652](https://github.com/graphiti-api/graphiti/commit/9e00652e124a411a2916d0fef52dc4fd2dc59020))
* require active_support so graphiti boots without Rails ([d431a03](https://github.com/graphiti-api/graphiti/commit/d431a0328fb4071429f39f4c69cda9c6cee308f2))


### Code Refactoring

* bridge the remaining 1.x names ([3d80ef9](https://github.com/graphiti-api/graphiti/commit/3d80ef98cf765a152032b7fed89b3cdc10be23dc))


### Features

* belongs_to renders resource linkage by default ([024824d](https://github.com/graphiti-api/graphiti/commit/024824d319619811ade886c72ce345cfeb584dbc)), closes [#168](https://github.com/graphiti-api/graphiti/issues/168) [#185](https://github.com/graphiti-api/graphiti/issues/185) [#167](https://github.com/graphiti-api/graphiti/issues/167) [#167](https://github.com/graphiti-api/graphiti/issues/167)
* fold graphiti_spec_helpers into graphiti ([da955a1](https://github.com/graphiti-api/graphiti/commit/da955a1e090ba44be31bf043ed90baa6661a4772))
* fold graphiti-rails into graphiti ([7740f8a](https://github.com/graphiti-api/graphiti/commit/7740f8a5803f1fbf02ef4e27d8baa6e0809d2b43)), closes [graphiti-rails#52](https://github.com/graphiti-rails/issues/52)
* handle exceptions with rescue_registry, fold in graphiti_errors ([e48171c](https://github.com/graphiti-api/graphiti/commit/e48171c117e7b8141fb6f966a972b0c1cd50c5ab))
* require Ruby 3.2 and Rails 7.1 ([635b249](https://github.com/graphiti-api/graphiti/commit/635b249a99f7d1ef726ae2328707ee6210cc0608))


### BREAKING CHANGES

* nothing removed, everything warns and goes away in 3.0. Except `include GraphitiErrors`, which now raises, as rescue_registry replaced it, so there's nothing to point it at.
* graphiti_errors is no longer a dependency and must be removed from the Gemfile, along with any `include GraphitiErrors`.

GraphitiErrors::Validation::Serializer is now Graphiti::ErrorSerializers::Validation, and GraphitiErrors.enable!/disable! becomes handle_request_exceptions. 409 responses now report code "conflict" and title "Conflict Error".
* Ruby >= 3.2 and Rails >= 7.1 are now required.
* remove graphiti-rails from your Gemfile. Controllers serving Graphiti resources must `include Graphiti::Rails::Controller` — previously every controller received it whether it wanted it or not. Graphiti::Responders is now Graphiti::Rails::Responders.
* remove graphiti_spec_helpers from your Gemfile. Prefer Graphiti::SpecHelpers and "graphiti/spec_helpers/rspec"; the old namespace and require paths still resolve, warn, and are removed in 3.0.

# [2.0.0-beta.3](https://github.com/graphiti-api/graphiti/compare/v2.0.0-beta.2...v2.0.0-beta.3) (2026-07-31)


### Features

* carry the assigned model on the resource, not through override signatures ([8ad848d](https://github.com/graphiti-api/graphiti/commit/8ad848d9bcd24cd63efb67e8ce32d5c8f3cfe147))

# [2.0.0-beta.2](https://github.com/graphiti-api/graphiti/compare/v2.0.0-beta.1...v2.0.0-beta.2) (2026-07-30)


### Features

* add Resource.wrap as an easy way to use graphiti serialization on models fetched via other means (and not via graphiti's finders) ([#513](https://github.com/graphiti-api/graphiti/issues/513)) ([fcd19e2](https://github.com/graphiti-api/graphiti/commit/fcd19e2d023091d85947dbdd89259b587e0f582b))
* deprecate mutating attributes in around_persistence hooks ([#514](https://github.com/graphiti-api/graphiti/issues/514)) [skip ci] ([8410ab0](https://github.com/graphiti-api/graphiti/commit/8410ab0a916077601cf85d8260a05ef9098149eb))

# [2.0.0-beta.1](https://github.com/graphiti-api/graphiti/compare/v1.12.2...v2.0.0-beta.1) (2026-07-30)


### Features

* drop Ruby 2.7 and Rails 5.2 support ([e905ddb](https://github.com/graphiti-api/graphiti/commit/e905ddb5c842299ffbfe5ec3c4ff98ec9b603a51))
* the model you inspect is the model that saves ([#465](https://github.com/graphiti-api/graphiti/issues/465)) ([a905fff](https://github.com/graphiti-api/graphiti/commit/a905fffc3a2aa5e663ff4cadcd632e68f053c81a))


### BREAKING CHANGES

* around_persistence hooks receive the assigned model instead of the attributes hash. Move attribute-hash modifications to before_attributes, or set values on the model. Custom create/update overrides that should receive a pre-assigned model must accept an assigned_model: keyword. See UPGRADING.md
* Ruby >= 3.0 / Rails >= 6 are now required.

# [1.13.0](https://github.com/graphiti-api/graphiti/compare/v1.12.2...v1.13.0) (2026-07-30)


### Features

* add Resource.wrap as an easy way to use graphiti serialization on models fetched via other means (and not via graphiti's finders) ([#513](https://github.com/graphiti-api/graphiti/issues/513)) ([fcd19e2](https://github.com/graphiti-api/graphiti/commit/fcd19e2d023091d85947dbdd89259b587e0f582b))
* deprecate mutating attributes in around_persistence hooks ([#514](https://github.com/graphiti-api/graphiti/issues/514)) [skip ci] ([8410ab0](https://github.com/graphiti-api/graphiti/commit/8410ab0a916077601cf85d8260a05ef9098149eb))

## [1.12.2](https://github.com/graphiti-api/graphiti/compare/v1.12.1...v1.12.2) (2026-07-29)


### Bug Fixes

* improve InvalidEndpoint guidance ([#512](https://github.com/graphiti-api/graphiti/issues/512)) ([1e6db50](https://github.com/graphiti-api/graphiti/commit/1e6db50b949505ebf4d587bb08c7711a9c771b13))

## [1.12.1](https://github.com/graphiti-api/graphiti/compare/v1.12.0...v1.12.1) (2026-07-29)


### Performance Improvements

* skip promise machinery when concurrency is disabled ([#510](https://github.com/graphiti-api/graphiti/issues/510)) ([b2e5f37](https://github.com/graphiti-api/graphiti/commit/b2e5f37428f7628b9fadd03823bd68552e125af0)), closes [#472](https://github.com/graphiti-api/graphiti/issues/472) [#497](https://github.com/graphiti-api/graphiti/issues/497) [#505](https://github.com/graphiti-api/graphiti/issues/505)

# [1.12.0](https://github.com/graphiti-api/graphiti/compare/v1.11.1...v1.12.0) (2026-07-29)


### Bug Fixes

* GQL name chaining ([#415](https://github.com/graphiti-api/graphiti/issues/415)) [skip ci] ([930928a](https://github.com/graphiti-api/graphiti/commit/930928a8779037efbcc1989eef5cf579c608e431))


### Features

* conditional relationships evaluate readable/writable guards per-request ([#450](https://github.com/graphiti-api/graphiti/issues/450)) ([3ed3187](https://github.com/graphiti-api/graphiti/commit/3ed3187068d268cd85ee1c36dc8135aa92abd05c))
* pass the model and attribute name to writable guards ([#511](https://github.com/graphiti-api/graphiti/issues/511)) [skip ci] ([24a8a94](https://github.com/graphiti-api/graphiti/commit/24a8a94f801867f57cc7c1ae9c6a9bdbfec05c24))

## [1.11.1](https://github.com/graphiti-api/graphiti/compare/v1.11.0...v1.11.1) (2026-07-28)

# [1.11.0](https://github.com/graphiti-api/graphiti/compare/v1.10.3...v1.11.0) (2026-07-28)


### Bug Fixes

* filter instead of failing for nil string values ([#503](https://github.com/graphiti-api/graphiti/issues/503)) ([44bf76c](https://github.com/graphiti-api/graphiti/commit/44bf76c1d519f3d7bfa31f08e88dfcc61cc56455))


### Features

* adds attr_reader to Graphiti::Errors::UnsupportedOperator ([#506](https://github.com/graphiti-api/graphiti/issues/506)) ([315cc30](https://github.com/graphiti-api/graphiti/commit/315cc30bad69485d7c5c5f02a0d515b67382281f))

## [1.10.3](https://github.com/graphiti-api/graphiti/compare/v1.10.2...v1.10.3) (2026-07-28)


### Bug Fixes

* declare ostruct runtime dependency for Ruby 3.5+ ([#508](https://github.com/graphiti-api/graphiti/issues/508)) ([38ef5c5](https://github.com/graphiti-api/graphiti/commit/38ef5c55b437b2cd42049405f8e98e991939b0fb))

## [1.10.2](https://github.com/graphiti-api/graphiti/compare/v1.10.1...v1.10.2) (2026-03-18)


### Bug Fixes

* Ensure RequestValidator validates resource relationships ([ddb5ad2](https://github.com/graphiti-api/graphiti/commit/ddb5ad2b69330774bd1a47935ed89a9fe4396a54))

## [1.10.1](https://github.com/graphiti-api/graphiti/compare/v1.10.0...v1.10.1) (2026-01-09)


### Bug Fixes

* make parse_fieldset more resilient ([#502](https://github.com/graphiti-api/graphiti/issues/502)) ([216213b](https://github.com/graphiti-api/graphiti/commit/216213bb643566e644c53727557a8e8c163ae6a1))

# [1.10.0](https://github.com/graphiti-api/graphiti/compare/v1.9.0...v1.10.0) (2026-01-06)


### Features

* add cache tag support to allow context-aware caching ([#498](https://github.com/graphiti-api/graphiti/issues/498)) ([e8c2bad](https://github.com/graphiti-api/graphiti/commit/e8c2bad478cb3dd8dbd1a5e993b10f84046a0fa8))

# [1.9.0](https://github.com/graphiti-api/graphiti/compare/v1.8.2...v1.9.0) (2026-01-03)


### Features

* Support rails 8.1 ([#500](https://github.com/graphiti-api/graphiti/issues/500)) ([34d0cf0](https://github.com/graphiti-api/graphiti/commit/34d0cf03b6b4d887d10d660f0ae08bfa6833345f))

## [1.8.2](https://github.com/graphiti-api/graphiti/compare/v1.8.1...v1.8.2) (2025-05-20)


### Bug Fixes

* prevent context loss by always setting thread and fiber locals ([#497](https://github.com/graphiti-api/graphiti/issues/497)) ([5f45f76](https://github.com/graphiti-api/graphiti/commit/5f45f76f590a8a15e9ae3d47d0673c483da11e66))

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
