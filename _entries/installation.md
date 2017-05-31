---
sectionid: installation
sectionclass: h1
title: Installation
number: 3
---

If you're using Rails:

```ruby
# Gemfile
gem 'jsonapi_suite', '~> 0.5'
gem 'jsonapi-rails', '~> 0.1'

group :test do
  gem 'jsonapi_spec_helpers', require: false
end

# config/initializers/jsonapi.rb
# Require the ActiveRecord adapter if needed
require 'jsonapi_compliable/adapters/active_record'

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include JsonapiSuite::ControllerMixin
end
```

Without Rails:

```ruby
# Gemfile
gem 'jsonapi_suite'

group :test do
  gem 'jsonapi_spec_helpers', require: false
end

# Include the module where appropriate
# For example, in Sinatra:

class TwitterApp < Sinatra::Application
  # Only Compliable is tested without Rails atm
  include JsonapiCompliable

  configure do
    mime_type :jsonapi, 'application/vnd.api+json'
  end

  before do
    content_type :jsonapi
  end
end
```

This suite is built on top of the mighty [jsonapi-rb](http://jsonapi-rb.org),
 hat tip [@beauby](https://github.com/beauby). Please read up on
 jsonapi-rb to understand serialization.

 <div style="height: 2rem;"></div>

{::options parse_block_html="true" /}
<div class='note info'>
###### Pagination Libraries
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
