---
sectionid: installation
sectionclass: h1
title: Installation
number: 3
---

To get up and running, we need to install the gem and include a few
modules. We're making this a manual step so the code is more obvious
to an outside developer:

```ruby
# Gemfile
gem 'jsonapi_suite'

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include JsonapiSuite::ControllerMixin
end

# create app/serializers/application_serializer.rb
# All serializers should subclass ApplicationSerializer
class ApplicationSerializer < ActiveModel::Serializer
  include JsonapiAmsExtensions
end
```

This suite depends on [active_model_serializers](github.com/rails-api/active_model_serializers). However, to accomodate a [performance issue](https://github.com/rails-api/active_model_serializers/pull/1931), we currently suggest you run off of this fork:

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

  If you'd prefer to use a different pagination scheme, [see the
  customization section](#without-kaminari)
  </div>
</div>
<div style="height: 20rem;" />
