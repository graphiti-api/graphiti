### JsonapiCompliable

[![Build Status](https://travis-ci.org/jsonapi-suite/jsonapi_compliable.svg?branch=master)](https://travis-ci.org/jsonapi-suite/jsonapi_compliable)

[JSONAPI Suite Website](https://jsonapi-suite.github.io/jsonapi_suite)

[Documentation](https://jsonapi-suite.github.io/jsonapi_compliable)

Supported Rails versions: >= 4.1

### Running tests

We support Rails >= 4.1. To do so, we use the [appraisal](https://github.com/thoughtbot/appraisal) gem. So, run:

```bash
$ bin/appraisal rails-4 bin/rspec
$ bin/appraisal rails-5 bin/rspec
```

Or run tests for all versions:

```bash
$ bin/appraisal bin/rspec
```

### Generating the Documentation

```bash
$ yard doc
$ yard server
```
