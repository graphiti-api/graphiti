# Contributing

## Commit messages

Releases are cut automatically by [semantic-release](https://github.com/semantic-release/semantic-release)
from commit messages, so the prefix you use decides whether a release happens
and how the version changes.

Format: `type: subject`, or `type(scope): subject`.

### Types that release

| Prefix | Version bump | Use for |
| ------ | ------------ | ------- |
| `fix:` | patch (`1.2.3` → `1.2.4`) | A bug fix users would notice |
| `perf:` | patch | A performance improvement |
| `feat:` | minor (`1.2.3` → `1.3.0`) | New functionality |

### Types that do not release

`build:` `chore:` `ci:` `docs:` `refactor:` `style:` `test:`

These land on `main` without publishing a gem. Use them for anything with no
user-facing change — test fixes, CI tweaks, internal refactors. They are still
included in the next release's notes.

### Breaking changes

Either add `!` after the type, or a `BREAKING CHANGE:` footer. Both produce a
major bump (`1.2.3` → `2.0.0`):

```
feat!: remove deprecated sideload API
```

```
feat: replace sideload API

BREAKING CHANGE: `allow_sideload` no longer accepts a :scope option.
```

The `!` works with a scope too: `feat(adapters)!: ...`

Describe what breaks and what to do instead — the footer text is published in
the release notes verbatim.

### Notes

- Only the **commit** prefix matters, not the PR title, unless the PR is
  squash-merged with the title as the commit subject.
- The prefix must be lowercase and followed by `: ` — `Fix: thing` and
  `fix:thing` are both unparsed, and an unparsed commit never triggers a
  release.
- If nothing since the last tag is `fix:`, `perf:`, `feat:`, or breaking, no
  release is cut. That is expected.

## Running the tests

```sh
bundle exec rspec
```

The Rails integration specs are gated behind an environment variable and are
**silently skipped** without it — a plain `rspec` run reports success while
covering none of the ActiveRecord adapter:

```sh
BUNDLE_GEMFILE=gemfiles/rails_8_0.gemfile \
  APPRAISAL_INITIALIZED=1 \
  bundle exec rspec spec/integration/rails/
```

Lint with:

```sh
bundle exec standardrb
```

CI fails PRs that don't pass lint, and almost everything standard flags is auto-fixable — run `bundle exec standardrb --fix` before pushing. (A bare `rake` also runs lint before the specs.)
