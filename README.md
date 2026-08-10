### Graphiti

[![CI](https://github.com/graphiti-api/graphiti/actions/workflows/ci.yml/badge.svg)](https://github.com/graphiti-api/graphiti/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/graphiti.svg)](https://badge.fury.io/rb/graphiti)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![semantic-release: angular](https://img.shields.io/badge/semantic--release-angular-e10079?logo=semantic-release)](https://github.com/semantic-release/semantic-release)


[![discord](https://img.shields.io/badge/community-discord-8A2BE2?logo=discord)](https://discord.gg/wgqkMBsSRV)
[![guides](https://img.shields.io/badge/guides-https://www.graphiti.dev-F565A5)](https://www.graphiti.dev)



<img align="right" src="https://user-images.githubusercontent.com/55264/54884141-c10ada00-4e43-11e9-866b-e3c01e33a7c7.png" alt="Graphiti logo" width="150px" />

Graphiti sits on top of your models (usually ActiveRecord) and exposes them over a JSON:API-compliant interface. You define Resources instead of controllers and serializers, and get filtering, sorting, pagination, sparse fieldsets, statistics, and nested reads and writes across relationships, all over one endpoint.

It's built on the [JSON:API](https://jsonapi.org) spec, which settles the decisions every API accumulates: response shapes, filtering, sorting, pagination, error formats, and how related data rides along. Your client layer speaks this protocol in return. It isn't complicated, so client logic can be hand-rolled or you can use one of the [many available libraries](https://jsonapi.org/implementations/#client-libraries) that work with the standard.

A Resource looks like this:

```ruby
class EmployeeResource < ApplicationResource
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :age, :integer

  has_many :positions
end
```

That Resource serves `?filter[age][gt]=30`, `?sort=-age`, `?page[size]=10`, `?include=positions` and more, without writing any of them. See [graphiti.dev](https://www.graphiti.dev/) for the whole loop, or the [example app](https://github.com/graphiti-api/employee_directory/) for a full working API.

### Documentation

Docs live at [graphiti.dev](https://www.graphiti.dev/) and are rendered from this repo: the markdown is in [`/docs`](docs), and the Docusaurus site that serves it is in [`/website`](website). Fixes and improvements are welcome (every page has an "Edit this page" link at the bottom, which makes opening a PR with a change easy).

To preview locally:

```bash
cd website
npm install
npm run start
```

[Join the Discord](https://discord.gg/wgqkMBsSRV)
