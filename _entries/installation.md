---
sectionid: installation
sectionclass: h1
title: Installation
number: 3
---

To get up and running, we need to install the gem and include a few
modules.

```ruby
# Gemfile
gem 'jsonapi_suite'

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include JsonapiSuite::ControllerMixin
end

# create app/serializers/application_serializer.rb
class ApplicationSerializer < ActiveModel::Serializer
  include JsonapiAmsExtensions
end
```

In addition, this suite depends on [active_model_serializers](github.com/rails-api/active_model_serializers). However, to accomodate a [performance issue](https://github.com/rails-api/active_model_serializers/pull/1931), we currently suggest you run off of this fork:

```ruby
gem 'active_model_serializers',
  git: 'https://github.com/richmolj/active_model_serializers.git',
  branch: 'include_data_if_sideloaded'
```

{::options parse_block_html="true" /}
<div class='note info'>
###### Pagination
  <div class='note-content'>
  While not a requirement, you can get out-of-the-box pagination with any gem that adds `per` and `page` methods to your ActiveRecord scopes. We recommend `kaminari`:

```ruby
# Gemfile
gem 'kaminari'
```
  </div>
</div>
<div style="height: 15rem;" />
