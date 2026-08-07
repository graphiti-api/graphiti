---
title: 'Upgrading to Graphiti 2.0'
---

# Upgrading to Graphiti 2.0
Graphiti 2.0 requires **Ruby 3.2+** and **ActiveSupport 7.1+**. Rails stays optional, and 7.1+ if you use it. It also folds `graphiti-rails`, `graphiti_spec_helpers` and `graphiti_errors` into `graphiti` itself. Those three gems are retired.

For most apps the upgrade is three things:

1. Remove `graphiti-rails`, `graphiti_spec_helpers` and `graphiti_errors` from your Gemfile.
2. Add `include Graphiti::Rails::Controller` to the controllers serving your resources.
3. Update `around_persistence` hooks, if you have any. They now receive the model rather than the attributes hash.

Old names still resolve and warn, so nothing breaks halfway through. They are removed in 3.0.

The [full upgrade guide](https://github.com/graphiti-api/graphiti/blob/main/UPGRADING.md) lists every rename, what was removed outright, and the migration path for apps not running Rails.
