---
layout: page
---

<div markdown="1" class="toc col-md-3">
Testing
==========

* 1 [Overview](#overview)
  * [API vs Resource](#api-vs-resource)
  * [Factories](#factories)
  * [RSpec](#rspec)
* 2 [Test Helpers](#test-helpers)
  * [`#jsonapi_data`](#jsonapidata)
    * [Accessing Sideloads](#accessing-sideloads)
    * [Accessing Links](#accessing-links)
  * [`json`](#json)
  * [`datetime`](#datetime)
  * [`jsonapi_errors`](#jsonapierrors)
  * [Resource Test Helpers](#resource-test-helpers)
  * [API Test Helpers](#api-test-helpers)
* 3 [Resource Tests](#resource-tests)
  * [Reads](#reads)
    * [Serialization](#serialization)
    * [Filtering](#filtering)
    * [Sorting](#sorting)
    * [Sideloading](#sideloading)
  * [Writes](#writes)
    * [Create](#create)
      * [Required belongs_to](#required-belongs-to)
    * [Update](#update)
    * [Destroy](#destroy)
    * [Side Effects](#side-effects)
* 4 [API Tests](#api-tests)
  * [Reads](#reads-1)
    * [Index](#index)
    * [Show](#show)
  * [Writes](#writes-1)
    * [Create](#create-1)
    * [Update](#update-1)
    * [Destroy](#destroy-1)
* 5 [Context](#context)
* 6 [Schema Validation](#schema-validation)
* 7 [Testing Spectrum](#testing-spectrum)
* 8 [Double-Testing Units](double-testing-units)
* 9 [Generators](#generators)

</div>

<div markdown="1" class="col-md-8">
## 1 Overview

Test first.

Wait, hear me out!

[Even if you're not a fan of TDD](http://david.heinemeierhansson.com/2014/tdd-is-dead-long-live-testing.html), Graphiti *integration* tests are simply the easiest, most pleasant way to develop. In fact, most Graphiti development can happen without even opening a browser...and as a side effect, you get a reliable test suite.

Let's say we want to filter Employees by `title`, which comes from
the `positions` table. Start with a spec:

{% highlight ruby %}
RSpec.describe EmployeeResource, type: :resource do
  describe 'filtering' do
    context 'by title' do
      # GIVEN some seed data
      let!(:employee1) { create(:employee) }
      let!(:employee2) { create(:employee) }
      let!(:position1) do
        create :position,
          title: 'foo',
          employee: employee1
      end
      let!(:position2) do
        create :position,
          title: 'bar',
          employee: employee2
      end

      # WHEN a parameter is set
      before do
        params[:filter] = { title: 'bar' }
      end

      # THEN the query results will be correct
      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end
  end
end
{% endhighlight %}

By developing test-first:

* We don't need to struggle with seeding local development data or
finding the right records for specific scenarios - we can
seed randomized data on-the-fly with [factories](https://github.com/thoughtbot/factory_bot).
* There's no need to spin up a server and refresh browser pages,
mentally parsing the response payload.
* We get a high-confidence test "for free".
* Because our integration test is separate from implementation, we don't
need to worry about [test-induced design damage](http://david.heinemeierhansson.com/2014/test-induced-design-damage.html).

### 1.1 API vs Resource

There are two types of Graphiti tests: **API tests** and **Resource
tests**.

This is because the same Resource logic can be re-used at multiple
endpoints. PostResource can be referenced at `/posts` and `/top_posts`
and `/admin/posts`, but we shouldn't have to test the same filtering and
sorting logic over and over. Querying, Persistence and Serialization are
all Resource responsibilities, tested in Resource tests.

We still want API tests, though, to test everything outside of the
Resource: routing, middleware, cache rules, response codes, etc.

Typically, you'll write the API test **once** and not have to touch it
again.

### 1.2 Factories

> Note: Factories are not **required**, but they are considered a best
> practice used by the Graphiti test generator. Read Thoughtbot's
> [Why Factories?](https://robots.thoughtbot.com/why-factories) for more
> information.

We need to seed data into our test database. To do this, we use [Factory
Bot](https://github.com/thoughtbot/factory_bot) and [Faker](https://github.com/stympy/faker).

When you generate a model, a stub factory will be created. It is highly
recommended you edit that factory with randomized data:

{% highlight ruby %}
# BEFORE
FactoryBot.define do
  factory :employee do
    first_name { 'MyString' }
  end
end

# AFTER
FactoryBot.define do
  factory :employee do
    first_name { Faker::Name.first_name }
  end
end
{% endhighlight %}

This will help catch edge cases and provide more clarity than seeing the
same `"MyString"` everywhere.

It's a best practice that if a factory defines an attribute, there
should be a corresponding validation around that attribute. If an
attribute is optional, it should not be defaulted in a factory.

Finally, [Rails 5 made belongs_to required by default](https://blog.bigbinary.com/2016/02/15/rails-5-makes-belong-to-association-required-by-default.html). This means that if Employee `belongs_to :department`, then `create(:employee)` will fail. To ensure a relationship is always seeded:

{% highlight ruby %}
FactoryBot.define do
  factory :employee do
    department
    # OR association :department, factory: :department
  end
end

{% endhighlight %}

### 1.3 RSpec

RSpec is not **required**, but considered a first-class citizen used by the
Graphiti test generator.

## 2 Test Helpers

Tests are run using [JSONAPI standards](http://jsonapi.org/format/#fetching-includes). But the
JSONAPI payload can be a pain to deal with. So, we've supplied helpers.

These helpers are defined in the [Graphiti Spec Helpers](https://github.com/graphiti-api/graphiti_errors) gem.

### 2.1 `#jsonapi_data`

> Note: for brevity, this method is aliased to `d`

The `jsonapi_data` method will parse response data and return a
normalized object (`GraphitiSpecHelpers::Node`). Assert against this the same way you assert against
JSON:

{% highlight ruby %}
data = jsonapi_data[0]
expect(data.id).to eq(employee.id)
expect(data.jsonapi_type).to eq('employees')
expect(data.first_name).to eq('Jane')
{% endhighlight %}

* `id` will automatically case to an integer. If you would like to avoid
this, use `rawid` instead.
* `jsonapi_type` is a convenience method for `data/type`, to avoid
conflicting with an attribute of the same name.
* If the `first_name` key was not present in the response, an error will
be raised.

#### 2.2 Accessing Sideloads

To grab a relationship:

{% highlight ruby %}
sideload = d[0].sideload(:comments)
expect(sideload.id).to eq(123)
expect(sideload.jsonapi_type).to eq('comments')
expect(sideload.body).to eq('body')
{% endhighlight %}

The `sideload` method accepts the *name of the relationship*. It returns
a normal `jsonapi_data` Node containing the `included` data.

#### 2.3 Accessing Links

To grab a Link:

{% highlight ruby %}
d[0].link(:comments, :related)
{% endhighlight %}

This accepts the relationship name and the link type. It will return the
link URL.

### 2.2 `#json`

To see the raw JSON response, just type `json`.

### 2.3 `#datetime`

In Graphiti, datetimes are rendered in [ISO 8601 format](https://www.iso.org/iso-8601-date-and-time-format.html). This means that straight date comparisons will fail:

{% highlight ruby %}
# WRONG
expect(d[0].created_at).to eq(post.created_at)
{% endhighlight %}

Instead, use the `datetime` helper to convert to ISO 8601 and compare
apples to apples:

{% highlight ruby %}
# RIGHT
expect(d[0].created_at).to eq(datetime(post.created_at))
{% endhighlight %}

### 2.4 `#jsonapi_errors`

> This method is aliased to `errors` for brevity

To parse an [Errors Payload](http://jsonapi.org/format/#errors):

{% highlight ruby %}
errors = jsonapi_errors

# Direct access
expect(errors.length).to eq(1)
expect(errors[0].attribute).to eq(:name)
expect(errors[0].status).to eq('422')
expect(errors[0].title).to eq('Validation Error')
expect(errors[0].detail).to eq("Name can't be blank")
expect(errors[0].code).to eq(:blank)
expect(errors[0].message).to eq("can't be blank")

# By attribute
expect(errors.name.message).to eq("can't be blank")
expect(errors.name.code).to eq(:blank)
# ... etc ...

# As a hash
expect(errors.to_h).to eq({
  name: "can't be blank"
})
{% endhighlight %}

### 2.5 Resource Test Helpers

Resource tests have two helpers, both different ways to execute a query.

`render` will fire the query and return a JSON response that can be
accessed as normal:

{% highlight ruby %}
it 'works' do
  render
  expect(d[0].first_name).to eq('Jane')
  json # => { data: { type: 'employees', ... } }
end
{% endhighlight %}

`records` will return model instances:

{% highlight ruby %}
it 'works' do
  render
  expect(records.map(&:id)).to eq([1, 2, 3])
end
{% endhighlight %}

### 2.6 API Test Helpers

When executing an API test request, always use the `jsonapi_`
dopplegangers:

* `jsonapi_get(url, params:)` instead of `get`
* `jsonapi_post(url, payload)` instead of `post`
* `jsonapi_put(url, payload)` instead of `put`
* `jsonapi_patch(url, payload)` instead of `patch`
* `jsonapi_delete(url)` instead of `delete`

This will set the `CONTENT_TYPE` header to `application/vnd.api+json`
and call `to_json` on the payload (when applicable).

It also allows overriding `jsonapi_headers`. Use this to manipulate
headers for a given request:

{% highlight ruby %}
def jsonapi_headers
  {}.tap do |headers|
    headers['CUSTOM'] = 'foo'
  end
end
{% endhighlight %}

## 3 Resource Tests

There are two test files for each Resource:

* `spec/resources/post/reads_spec.rb`
* `spec/resources/post/writes_spec.rb`

### 3.1 Reads

The basic setup for read operations:

{% highlight ruby %}
# spec/resources/employee/reads_spec.rb
require 'rails_helper'

RSpec.describe EmployeeResource, type: :resource do
  describe 'serialization' do
    # ... code ...
  end

  describe 'filtering' do
    # ... code ...
  end

  describe 'sorting' do
    # ... code ...
  end

  describe 'sideloading' do
    # ... code ...
  end
end
{% endhighlight %}

#### 3.1.1 Serialization

{% highlight ruby %}
describe 'serialization' do
  let!(:employee) { create(:employee, first_name: 'Jane') }

  it 'works' do
    render
    data = jsonapi_data[0]
    expect(data.id).to eq(employee.id)
    expect(data.jsonapi_type).to eq('employees')
    expect(data.first_name).to eq('Jane')
  end
end
{% endhighlight %}

We want to test that our attributes render correctly. We'll do this by
seeding a record, firing a basic query, and comparing the JSON result to
the seeded data.

Best practices:

* Assert on all attributes, even if there is no logic. This way adding
logic will cause a test failure.
* When seeding data, manually assign values. This way you can be assured
you aren't accidentally testing `nil == nil`

If you decide you have a high level of confidence in your factories, you
can instead save some keystrokes and assert on randomized data:

{% highlight ruby %}
expect(data.first_name).to eq(employee.first_name)
{% endhighlight %}

> Note: Our schema validation test will ensure no attributes get
> removed or change types.

#### 3.1.2 Filtering

{% highlight ruby %}
describe 'filtering' do
  let!(:employee1) { create(:employee) }
  let!(:employee2) { create(:employee) }

  context 'by id' do
    before do
      params[:filter] = { id: { eq: employee2.id } }
    end

    it 'works' do
      render
      expect(d.map(&:id)).to eq([employee2.id])
    end
  end
end
{% endhighlight %}

Here we seed data, set the filter parameter, and assert only records
matching the given criteria are present in the response.

In general, you only need to test filtering when there is custom logic.
Our schema validation test will ensure no filters are removed, guarded,
changed operators, etc.

#### 3.1.3 Sorting

{% highlight ruby %}
describe 'sorting' do
  describe 'by id' do
    let!(:employee1) { create(:employee) }
    let!(:employee2) { create(:employee) }

    context 'when ascending' do
      before do
        params[:sort] = 'id'
      end

      it 'works' do
        render
        expect(d.map(&:id)).to eq([
          employee1.id,
          employee2.id
        ])
      end
    end

    context 'when descending' do
      before do
        params[:sort] = '-id'
      end

      it 'works' do
        render
        expect(d.map(&:id)).to eq([
          employee2.id,
          employee1.id
        ])
      end
    end
  end
end
{% endhighlight %}

Here we seed data, set the sort parameter, and assert the correct order
of the rendered response.

In general, you only need to test sorting when there is custom logic.
Our schema validation test will ensure no sorts are removed, guarded or
limited in direction.

#### 3.1.4 Sideloading

{% highlight ruby %}
describe 'sideloading' do
  let!(:employee) { create(:employee) }

  describe 'current_position' do
    let!(:pos1) do
      create(:position, employee: employee, historical_index: 2)
    end
    let!(:pos2) do
      create(:position, employee: employee, historical_index: 1)
    end

    before do
      params[:include] = 'current_position'
    end

    it 'returns position with historical index == 1' do
      render
      sl = d[0].sideload(:current_position)
      expect(sl.jsonapi_type).to eq('positions')
      expect(sl.id).to eq(pos2.id)
    end
  end
end
{% endhighlight %}

Here we seed data, set the sideload parameter, and assert the correct
entity is present in the request. There is no need to test each
attribute of the sideload - this should be tested in the [Resource
Test](#resource-tests) of the sideloaded Resource.

In general, you only need to test sideloads when there is custom logic.
Our schema validation test will ensure no sideloads are removed or
associated to a different Resource.

### 3.2 Writes

The basic setup for write operations:

{% highlight ruby %}
# spec/resources/employee/writes_spec.rb
require 'rails_helper'

RSpec.describe EmployeeResource, type: :resource do
  describe 'creating' do
    let(:payload) { ... }
    # ... code ...
  end

  describe 'creating' do
    let(:payload) { ... }
    # ... code ...
  end

  describe 'destroying' do
    # ... code ...
  end
end
{% endhighlight %}

Here `payload` is a [JSONAPI Resource Object](http://jsonapi.org/format/#crud).

#### 3.2.1 Create

{% highlight ruby %}
describe 'creating' do
  let(:payload) do
    {
      data: {
        type: 'employees',
        attributes: { }
      }
    }
  end)

  let(:instance) do
    EmployeeResource.build(payload)
  end

  it 'works' do
    expect {
      expect(instance.save).to eq(true)
    }.to change { Employee.count }.by(1)
  end
end
{% endhighlight %}

Here `payload` is an empty Employee [Resource Object](http://jsonapi.org/format/#crud).
We'll assert that when saving this empty payload, an Employee is
created.

You'll likely want to add attributes here and ensure they are persisted
correctly:

{% highlight ruby %}
let(:payload) do
  {
    data: {
      type: 'employees',
      attributes: { first_name: 'Jane', age: 30 }
    }
  }
end

# ... code ...

it 'works' do
  expect {
    expect(instance.save).to eq(true)
  }.to change { Employee.count }.by(1)
  employee = Employee.last
  expect(employee.first_name).to eq('Jane')
  expect(employee.age).to eq(30)
end
{% endhighlight %}

##### 3.2.1.1 Required Belongs To

[Rails 5 made belongs_to required by default](https://blog.bigbinary.com/2016/02/15/rails-5-makes-belong-to-association-required-by-default.html). This means that if Employee `belongs_to :department`, the above tests will fail (we cannot create the Employee without associating it to Department).

You have 3 options here:

* Turn off this validation in test mode. Add `config.active_record.belongs_to_required_by_default = true` to `config/environments/test.rb`.
* Turn off the validation for this specific relationship: `belongs_to
:department) optional: true`
* Associate as part of the request.

We recommend the third option to preserve real-world end-to-end
behavior:

{% highlight ruby %}
describe 'creating' do
  let!(:department) { create(:department) }

  let(:payload) do
    {
      type: 'employees',
      attributes: { ... },
      relationships: {
        department: {
          data: {
            type: 'departments',
            id: department.id.to_s
          }
        }
      }
    }
  end

  # ... code ...
end
{% endhighlight %}

Will ensure the Employee is created and associated to the given
department.

#### 3.2.2 Update

{% highlight ruby %}
describe 'updating' do
  let!(:employee) { create(:employee) }

  let(:payload) do
    {
      data: {
        id: employee.id.to_s,
        type: 'employees',
        attributes: { first_name: 'changed!' }
      }
    }
  end

  let(:instance) do
    EmployeeResource.find(payload)
  end

  it 'works' do
    expect {
      expect(instance.update_attributes).to eq(true)
    }.to change { employee.reload.updated_at }
     .and change { employee.first_name }.to('changed!')
  end
end
{% endhighlight %}

> Note that this test will be pending by default when using the
> generator, as we require the attributes to be explicitly defined.

Here `payload` is an empty Employee [Resource Object](http://jsonapi.org/format/#crud).
We'll assert that when updating attributes, the changes are correctly
persisted to the database.

#### 3.2.3 Destroy

{% highlight ruby %}
describe 'destroying' do
  let!(:employee) { create(:employee) }

  let(:instance) do
    EmployeeResource.find(id: employee.id)
  end

  it 'works' do
    expect {
      expect(instance.destroy).to eq(true)
    }.to change { Employee.count }.by(-1)
  end
end
{% endhighlight %}

Here we ensure that a delete request correctly removes a record from the
database.

#### 3.2.4 Side Effects

{% highlight ruby %}
it 'works' do
  # some assertion
  email = ActionMailer::Base.deliveries.last
  expect(email.subject).to eq('Welcome!')
end
{% endhighlight %}

It's common for write operations to cause side-effects, such as sending
an email or updating an audit trail. It's recommended to test these
*within the same "it" block* unless the logic gets particularly intense.
Though "one expectation per test" works well for unit tests, integration
tests can take longer to run and the performance penalty isn't worth it.

## 4 API Tests

There are five test files for each Resource:

* `spec/api/v1/employees/index_spec.rb`
* `spec/api/v1/employees/show_spec.rb`
* `spec/api/v1/employees/create_spec.rb`
* `spec/api/v1/employees/update_spec.rb`
* `spec/api/v1/employees/destroy_spec.rb`

### 4.1 Reads

#### 4.1.1 `index`

{% highlight ruby %}
require 'rails_helper'

RSpec.describe "employees#index", type: :request do
  let(:params) { {} }

  subject(:make_request) do
    jsonapi_get "/api/v1/employees", params: params
  end

  describe 'basic fetch' do
    let!(:employee1) { create(:employee) }
    let!(:employee2) { create(:employee) }

    it 'works' do
      expect(EmployeeResource).to receive(:all).and_call_original
      make_request
      expect(response.status).to eq(200)
      expect(d.map(&:jsonapi_type).uniq)
        .to match_array(['employees'])
      expect(d.map(&:id))
        .to match_array([employee1.id, employee2.id])
    end
  end
end
{% endhighlight %}

Here we're ensuring `EmployeeResource` is the correct resource to be
called from this endpoint, we get a 200 status code, and the entities
returned are expected.

#### 4.1.2 `show`

{% highlight ruby %}
require 'rails_helper'

RSpec.describe "employees#show", type: :request do
  let(:params) { {} }

  subject(:make_request) do
    jsonapi_get "/api/v1/employees/#{employee.id}", params: params
  end

  describe 'basic fetch' do
    let!(:employee) { create(:employee) }

    it 'works' do
      expect(EmployeeResource).to receive(:find).and_call_original
      make_request
      expect(response.status).to eq(200)
      expect(d.jsonapi_type).to eq('employees')
      expect(d.id).to eq(employee.id)
    end
  end
end
{% endhighlight %}

Similar to `index`, but fetching only a single Employee.

### 4.2 Writes

#### 4.2.1 `create`

{% highlight ruby %}
require 'rails_helper'

RSpec.describe "employees#create", type: :request do
  subject(:make_request) do
    jsonapi_post "/api/v1/employees", payload
  end

  describe 'basic create' do
    let(:payload) do
      {
        data: {
          type: 'employees',
          attributes: {
            first_name: 'Jane'
          }
        }
      }
    end

    it 'works' do
      expect(EmployeeResource).to receive(:build).and_call_original
      expect {
        make_request
      }.to change { Employee.count }.by(1)
      expect(response.status).to eq(201)
    end
  end
end
{% endhighlight %}

Here we're ensuring EmployeeResource is called, a record is correctly
inserted, and the response code is `201`.

You probably only want to add attributes required to pass validation,
here - note that we don't assert on attributes of the created record
(save this for your Resource test). One easy way to do this is to pass
randomized data from your factory:

{% highlight ruby %}
let(:payload) do
  {
    data: {
      type: 'employees',
      attributes: attributes_for(:employee)
    }
  }
end
{% endhighlight %}

See also:

  * [Dealing with required belongs_to relationships](#required-belongs-to).

#### 4.2.2 `update`

{% highlight ruby %}
require 'rails_helper'

RSpec.describe "employees#update", type: :request do
  subject(:make_request) do
    jsonapi_put "/api/v1/employees/#{employee.id}", payload
  end

  describe 'basic update' do
    let!(:employee) { create(:employee) }

    let(:payload) do
      {
        data: {
          id: employee.id.to_s,
          type: 'employees',
          attributes: {
            first_name: 'changed!'
          }
        }
      }
    end

    it 'updates the resource' do
      expect(EmployeeResource).to receive(:find).and_call_original
      expect {
        make_request
      }.to change { employee.reload.attributes }
      expect(response.status).to eq(200)
    end
  end
end
{% endhighlight %}

Here we're ensuring EmployeeResource is called, attributes are updated,
and we respond with a 201. Note that we don't assert on specific
attributes - save that for your Resource test.

Just like the prior section, you may want to leverage FactoryBot here to
generate randomized attributes:

{% highlight ruby %}
let(:payload) do
  {
    data: {
      id: employee.id.to_s,
      type: 'employees',
      attributes: attributes_for(:employee)
    }
  }
end
{% endhighlight %}

#### 4.2.3 `destroy`

{% highlight ruby %}
require 'rails_helper'

RSpec.describe "employees#destroy", type: :request do
  subject(:make_request) do
    jsonapi_delete "/api/v1/employees/#{employee.id}"
  end

  describe 'basic destroy' do
    let!(:employee) { create(:employee) }

    it 'updates the resource' do
      expect(EmployeeResource).to receive(:find).and_call_original
      expect { make_request }.to change { Employee.count }.by(-1)
      expect { employee.reload }
        .to raise_error(ActiveRecord::RecordNotFound)
      expect(response.status).to eq(200)
      expect(json).to eq('meta' => {})
    end
  end
end
{% endhighlight %}

Here we're sending a DELETE request, ensuring the record is actually
removed, and we respond [according to the JSONAPI specification](http://jsonapi.org/format/#crud-deleting-responses-200).

# 5 Context

Occasionally you'll need to set context for tests. The most common
scenario is authorization:

{% highlight ruby %}
attribute :salary, :integer, readable: :admin?

def admin?
  context.current_user.admin?
end
{% endhighlight %}

When using Rails, `context` is the controller associated to the request.
We can manually set context in tests:

{% highlight ruby %}
let(:user) { double(admin?: true) }
let(:ctx) { double(current_user: user) }

it 'works' do
  Graphiti.with_context ctx do
    render
  end
  expect(d[0].salary).to eq(100_000)
end
{% endhighlight %}

<br />

# 6 Schema Validation

Graphiti comes with built-in backwards-compatibility tests. We do this
by comparing the current version of the schema with one previously
checked-in.

These tests are added at the bottom of `spec/rails_helper.rb`:

{% highlight ruby %}
GraphitiSpecHelpers::RSpec.schema!
{% endhighlight %}

Whenever you run tests, the schema check will *also* run. If we find any
backwards-incompatibilities - attributes removed, types changed, default
sort direction modified, etc - the schema test will fail with an output
detailing all incompatibilities.

When the schema test succeeds, it will overwrite the existing schema
file with the new schema. It will not do this on failure.

There are times when you want to accept an incompatibility and move on
anyway. In this case, use `FORCE_SCHEMA`:

{% highlight bash %}
$ FORCE_SCHEMA=true bin/rspec
{% endhighlight %}

<br />

# 7 Testing Spectrum

Testing standards vary from team to team, and there is no right answer
when judging "the right level of testing".

You *could* add tests for every attribute, validating every sort and
filter. Or, you could consider logicless configuration tested as part of
Graphiti itself (the same way we don't tend to test a `has_many`
ActiveRecord relationship). Though our guides favor the latter, the
extra tests could prove useful when performing a major upgrade or
swapping datastores.

You *could* do more API testing, particularly for high-value
functionality. Testing fully end-to-end, from middleware to response
codes, gives a high level of confidence. But it can also feel like
duplicate tests across endpoints, which is why we have Resource tests.

Graphiti provides sensible defaults, but you're encouraged to consider
the tradeoffs and pick the right level of testing for *you*.

# 7 Double-Testing Units

Integration testing is great: it gives a high level of confidence, and
they're typically the easiest tests to write. In fact, these tests are
so powerful the value of unit testing sometimes comes up for debate.

Consider a custom filter powered by an ActiveRecord scope:

{% highlight ruby %}
# app/resources/employee_resource.rb
filter :title, :string do
  eq do |scope, value|
    scope.by_title(value)
  end
end

# app/models/employee.rb
scope :by_title, ->(title) {
  joins(:current_position)
    .where("lower(title) = ?", title.downcase)
}
{% endhighlight %}

If we're by-the-book, we should absolutely test `.by_title` on the
Employee model. After all, we're exposing a public interface that other
developers might rely on in the future.

This can feel cumbersome, even duplicative. The Resource Test of the
title filter will seed the same data as the corresponding unit test, and
the assertion will be almost identical. But because Resource Tests are
*integration* tests, we shouldn't mock the code either.

The best practice here is to use [RSpec shared_context](https://relishapp.com/rspec/rspec-core/docs/example-groups/shared-context) to remove the duplication:

{% highlight ruby %}
# spec/support/employees_helper.rb
RSpec.shared_context 'employees by title' do
  let!(:employee1) { create(:employee) }
  let!(:employee2) { create(:employee) }
  let!(:employee3) { create(:employee) }
  let!(:position1) do
    create(:position, title: 'foo', employee: employee1)
  end
  let!(:position2) do
    create(:position, title: 'BAR', employee: employee2)
  end
  let!(:position3) do
    create(:position, title: 'bar', employee: employee3)
  end
end

# spec/models/employee.rb
describe '.by_title' do
  include_context 'employees by title'

  it 'returns employees matching the given title' do
    expect(Employee.by_title('bar'))
      .to eq([employee2, employee3])
  end
end

# spec/resources/employee_resource.rb
describe 'filtering' do
  describe 'by title' do
    include_context 'employees by title'

    before do
      params[:filter] = { title: 'bar' }
    end

    it 'returns employees matching the given title' do
      expect(records).to eq([employee2, employee3])
    end
  end
end
{% endhighlight %}

This **allows our `by_title` scope to be re-used by future developers
outside of the Resource context**. It also keeps code clean and
isolated.

But it's not unreasonable to think the overhead here isn't worth it. If
you're of this mind, we recommend testing the Resource and marking the
method as not re-usable:

{% highlight ruby %}
# @api private
scope :by_title, ->(value) { ... }
{% endhighlight %}

This way future developers know the scope is only an implementation
detail and not considered part of this object's public API. Writing the
unit test can be deferred until the use case actually arises.

## 9 Generators

The [Resource generator](/guides/concepts/resources#generators) will create both Resource and API tests for you.
Use these as templates to implement your tests.

You can also run

{% highlight bash %}
$ rails generate graphiti:api_test RESOURCE [options]
{% endhighlight %}

For example

{% highlight bash %}
$ rails generate graphiti:api_test EmployeeResource -a index show
{% endhighlight %}

To generate only the API tests. This can be particularly helpful because
API tests are mostly boilerplate that does not need to be manually
edited. Pass the `-a` option to limit RESTful actions.
