---
layout: page
---

Writing Specs
==========

> NB: before writing specs, make sure you are set up correctly by
> following the [Quickstart](quickstart)

Validating verbose JSON API responses in tests can be a pain. We could
use something like [json_matchers](https://github.com/thoughtbot/json_matchers) to validate a schema, but we hope to do one better - let's validate full payloads with a few simple helpers, using full-stack [rspec request specs](https://github.com/rspec/rspec-rails#request-specs).

Let's say we're testing the `show` action of our employees controller, sideloading the employee's department. Follow the [Quickstart](quickstart) to make sure your `rails_helper.rb` is setup correctly first.

Let's say we're testing the `show` action of our employees controller, sideloading the employee's department.

Let's begin with vanilla RSpec of what the test might look like:

{% highlight ruby %}
require 'rails_helper'

RSpec.describe 'employees#show', type: :request do
  let!(:homer)  { Employee.create!(name: 'Homer Simpson') }
  let!(:safety) { employee.create_department!(name: 'Safety') }

  it 'renders an employee, sideloading department' do
    get "/api/employees/#{homer.id}", params: {
      include: 'department'
    }
    # ... code asserting json response ...
  end
end
{% endhighlight %}

To avoid painful json assertions, let's use [jsonapi_spec_helpers](https://github.com/jsonapi-suite/jsonapi_spec_helpers). Start by adding some setup code:

{% highlight ruby %}
# spec/rails_helper.rb
require 'jsonapi_spec_helpers'

RSpec.configure do |config|
  config.include JsonapiSpecHelpers
end
{% endhighlight %}

And now to validate the response, we'll call `assert_payload`:

{% highlight ruby %}
assert_payload(:employee, homer, json_item)
assert_payload(:department, safety, json_include('departments'))
{% endhighlight %}

`assert_payload` takes three arguments:
* The name of a payload we've defined (we haven't done this yet).
* The record we want to compare against
* The relevant slice of json. `json_item` and `json_includes` are
  helpful methods to target the right slice. You can see all helpers in
the documentation for `jsonapi_spec_helpers`.

OK, so we want to take a record, response JSON, and compare them against
something pre-defined. Let's write those definitions; they look very similar to
something you'd write for [factory_girl](https://github.com/thoughtbot/factory_girl):

{% highlight ruby %}
# spec/payloads/employee.rb
JsonapiSpecHelpers::Payload.register(:employee) do
  key(:name)
  key(:email)

  timestamps!
end

# spec/payloads/department.rb
JsonapiSpecHelpers::Payload.register(:department) do
  key(:name)
end
{% endhighlight %}

`assert_payload` will do four things:

* Ensure keys that are not in the payload definition are **not** present.
* Ensure all keys in the registered payload **are** present.
* Ensures no value in a key/value pair is `nil` (this is overrideable).
* Ensures each key matches the expected record value. In other words,
  we're doing something like `expect(json['email']).to eq(homer.email)`.

The comparison value can be customized. Let's say we serialize the
`name` attribute as a combination of the employee's `first_name` and
`last_name`:

{% highlight ruby %}
key(:name) { |record| "#{record.first_name} #{record.last_name}" }
{% endhighlight %}

Optionally, validate against a type as well. If both the expected and
actual values match, but are the incorrect type, the test will fail:

{% highlight ruby %}
key(:salary, Integer)
{% endhighlight %}

You can also customize/override payloads at runtime in your test. Let's
say we only serialize `salary` when the current user is an admin. Your
test could look something like:

{% highlight ruby %}
sign_in(:user)
assert_payload(:employee, homer, json_item)
sign_in(:admin)
assert_payload(:employee, homer, json_item) do
  key(:salary)
end
{% endhighlight %}

For documentation on all the spec helpers we provide, check out the
[jsonapi_spec_helpers](https://github.com/jsonapi-suite/jsonapi_spec_helpers) gem.

<br />
<br />
