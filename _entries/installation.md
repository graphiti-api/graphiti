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

This suite is built on top of the mighty [jsonapi-rb](jsonapi-rb.org),
 hat tip [@beauby](https://github.com/beauby). Please read up on
 jsonapi-rb to understand serialization.

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
