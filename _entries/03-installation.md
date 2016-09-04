---
sectionid: installation
sectionclass: h1
title: Installation
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

In addition, this suite depends on [active_model_serializers](github.com/rails-api/active_model_serializers). However, to accomodate a [performance issue](https://github.com/rails-api/active_model_serializers/pull/1797), we currently suggest you run off of this fork:

```ruby
gem 'active_model_serializers',
  git: 'https://github.com/richmolj/active_model_serializers.git'
```

While not a requirement, you can get out-of-the-box pagination with any
gem that adds `per` and `page` methods to your ActiveRecord scopes. We
recommend `kamanari`:

```ruby
# Gemfile
gem 'kaminari'
```

You're ready to go!

todo: seed, model, migrate in subsection

todo: note activerecord not dependency, just example
