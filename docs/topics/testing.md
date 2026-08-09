---
title: 'Testing'
---

## Overview {#overview}

Test first.

Wait, hear me out!

[Even if you're not a fan of TDD](http://david.heinemeierhansson.com/2014/tdd-is-dead-long-live-testing.html), Graphiti *integration* tests are the easiest, most pleasant way to develop. In fact, most Graphiti development can happen without even opening a browser. And as a side effect, you get a reliable test suite.

Let's say we want to filter Employees by `title`, which comes from the `positions` table. Start with a spec:

```ruby
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
```

By developing test-first:

* We don't need to struggle with seeding local development data or finding the right records for specific scenarios - we can seed randomized data on-the-fly with [factories](https://github.com/thoughtbot/factory_bot).
* There's no need to spin up a server and refresh browser pages, mentally parsing the response payload.
* We get a high-confidence test "for free".
* Because our integration test is separate from implementation, we don't need to worry about [test-induced design damage](http://david.heinemeierhansson.com/2014/test-induced-design-damage.html).

### API vs Resource {#api-vs-resource}

There are two types of Graphiti tests: **API tests** and **Resource tests**.

This is because the same Resource logic can be re-used at multiple endpoints. PostResource can be referenced at `/posts`, `/top_posts`, and `/admin/posts`, but we shouldn't have to test the same filtering and sorting logic over and over. Querying, persistence, and serialization are all Resource responsibilities, tested in Resource tests.

We still want API tests, though, to test everything outside of the Resource: routing, middleware, cache rules, response codes, etc…

Typically, you'll write the API test **once** and not have to touch it again.

### Factories {#factories}

> Note: Factories are not **required**, but they are considered a best practice used by the Graphiti test generator. Read thoughtbot's [Why Factories?](https://robots.thoughtbot.com/why-factories) for more information.

We need to seed data into our test database. To do this, we use [Factory Bot](https://github.com/thoughtbot/factory_bot) and [Faker](https://github.com/stympy/faker).

When you generate a model, a stub factory will be created. It is highly recommended you edit that factory with randomized data:

```ruby
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
```

This will help catch edge cases and provide more clarity than seeing the same `"MyString"` everywhere.

It's a best practice that if a factory defines an attribute, there should be a corresponding validation around that attribute. If an attribute is optional, it should not be defaulted in a factory.

Finally, Rails requires `belongs_to` associations by default. This means that if Employee `belongs_to :department`, then `create(:employee)` will fail. To ensure a relationship is always seeded:

```ruby
FactoryBot.define do
  factory :employee do
    department
    # OR association :department, factory: :department
  end
end

```

### RSpec Setup {#rspec}

RSpec is not **required**, but considered a first-class citizen used by the Graphiti test generator.

Add the following to your Gemfile:

```ruby
# Gemfile
group :development, :test do
  gem 'factory_bot_rails'
  gem 'rspec_rails'
  gem 'faker'
end

group :test do
  gem 'database_cleaner'
end
```

Bootstrap RSpec if you haven't already:

```bash
$ bin/rails g rspec:install
```

Then wire up Graphiti's helpers and reset your database between examples:

```ruby
require 'graphiti/spec_helpers/rspec'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Graphiti::SpecHelpers::RSpec
  config.include Graphiti::Rails::TestHelpers, type: :request

  # Clean your DB between test runs
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    begin
      DatabaseCleaner.cleaning do
        example.run
      end
    ensure
      DatabaseCleaner.clean
    end
  end
end
```

## Test Helpers {#test-helpers}

Tests are run using [JSONAPI standards](http://jsonapi.org/format/#fetching-includes). But the JSONAPI payload can be a pain to deal with. So, we've supplied helpers.

These helpers ship with Graphiti, under `Graphiti::SpecHelpers`.

### #jsonapi_data {#jsonapi-data}

The `jsonapi_data` method will parse response data and return a normalized object (`Graphiti::SpecHelpers::Node`). Assert against this the same way you assert against JSON:

```ruby
data = jsonapi_data[0]
expect(data.id).to eq(employee.id)
expect(data.jsonapi_type).to eq('employees')
expect(data.first_name).to eq('Jane')
```

* `id` will automatically case to an integer. If you would like to avoid this, use `rawid` instead.
* `jsonapi_type` is a convenience method for `data/type`, to avoid conflicting with an attribute of the same name.
* If the `first_name` key was not present in the response, an error will be raised.

#### Accessing Sideloads {#accessing-sideloads}

To grab a relationship:

```ruby
sideload = jsonapi_data[0].sideload(:comments)
expect(sideload.id).to eq(123)
expect(sideload.jsonapi_type).to eq('comments')
expect(sideload.body).to eq('body')
```

The `sideload` method accepts the *name of the relationship*. It returns a normal `jsonapi_data` `Graphiti::SpecHelpers::Node` containing the `include`-ed data.

#### Accessing Links {#accessing-links}

To grab a Link:

```ruby
jsonapi_data[0].link(:comments, :related)
```

This accepts the relationship name and the link type. It will return the link URL.

### #json {#json}

To see the raw JSON response, use `json`.

### #json_date and #json_datetime {#date-and-datetime}

In Graphiti, datetimes are rendered in [ISO 8601 format](https://www.iso.org/iso-8601-date-and-time-format.html). This means that straight date comparisons will fail:

```ruby
# WRONG
expect(jsonapi_data[0].created_at).to eq(post.created_at)
```

Instead, use the `json_datetime` helper to convert to ISO 8601 and compare apples to apples:

```ruby
# RIGHT
expect(jsonapi_data[0].created_at).to eq(json_datetime(post.created_at))
```

Similarly, there's a `json_date` helper as well.

### #jsonapi_errors {#jsonapi-errors}

To parse an [Errors Payload](http://jsonapi.org/format/#errors):

```ruby
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
```

### Resource Test Helpers {#resource-test-helpers}

Resource tests have two helpers, both different ways to execute a query.

`render` will fire the query and return a JSON response that can be accessed as normal:

```ruby
it 'works' do
  render
  expect(jsonapi_data[0].first_name).to eq('Jane')
  json # => { data: { type: 'employees', ... } }
end
```

`records` will return model instances:

```ruby
it 'works' do
  render
  expect(records.map(&:id)).to eq([1, 2, 3])
end
```

### Resource Matchers {#resource-matchers}

For one-line assertions about a Resource's shape, use the built-in matchers. They're included automatically in `type: :resource` specs and expect a Resource instance as the subject:

```ruby
RSpec.describe PostResource, type: :resource do
  subject { described_class.new }

  it { is_expected.to belong_to_resource(:author) }
  it { is_expected.to have_many_resources(:comments) }
  it { is_expected.to have_one_resource(:detail) }
  it { is_expected.to expose_attribute(:title, :string) }
  it { is_expected.to filter_attribute(:title, :string) }
end
```

Each matcher accepts `with_options` to assert configuration:

```ruby
it do
  is_expected.to belong_to_resource(:author)
    .with_options(foreign_key: :author_id, resource: AuthorResource)
end

it { is_expected.to expose_attribute(:title, :string).with_options(writable: false) }
```

### API Test Helpers {#api-test-helpers}

When executing an API test request, always use the `jsonapi_` doppelgänger:

* `jsonapi_get(url, params:)` instead of `get`
* `jsonapi_post(url, payload)` instead of `post`
* `jsonapi_put(url, payload)` instead of `put`
* `jsonapi_patch(url, payload)` instead of `patch`
* `jsonapi_delete(url)` instead of `delete`

This will set the `CONTENT_TYPE` header to `application/vnd.api+json` and call `to_json` on the payload (when applicable).

It also allows overriding `jsonapi_headers`. Use this to manipulate headers for a given request:

```ruby
def jsonapi_headers
  super.tap do |headers|
    headers['CUSTOM'] = 'foo'
  end
end
```

### Guard Helpers {#guard-helpers}

Many teams use [guard](https://github.com/guard/guard) in development to watch their project files and run a smaller set of focused tests as code changes. For those teams leveraging guard and the [guard-rspec plugin](https://github.com/guard/guard-rspec), we offer an additional set of DSL helpers via the [guard-rspec-graphiti plugin](https://github.com/graphiti-api/guard-rspec-graphiti). For more details, check out the [project README](https://github.com/graphiti-api/guard-rspec-graphiti/blob/master/README.md).

## Resource Tests {#resource-tests}

There are two test files for each Resource:

* `spec/resources/post/reads_spec.rb`
* `spec/resources/post/writes_spec.rb`

### Reads {#reads}

The basic setup for read operations:

```ruby
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
```

#### Serialization {#serialization}

```ruby
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
```

Best practices:

* Assert on all attributes, even if there is no logic. This way adding logic will cause a test failure.
* When seeding data, manually assign values. This way you can be assured you aren't accidentally testing `nil == nil`

If you decide you have a high level of confidence in your factories, you can instead save some keystrokes and assert on randomized data:

```ruby
expect(data.first_name).to eq(employee.first_name)
```

> Note: Our schema validation test will ensure no attributes get removed or change types.

#### Filtering {#filtering}

```ruby
describe 'filtering' do
  let!(:employee1) { create(:employee) }
  let!(:employee2) { create(:employee) }

  context 'by id' do
    before do
      params[:filter] = { id: { eq: employee2.id } }
    end

    it 'works' do
      render
      expect(jsonapi_data.map(&:id)).to eq([employee2.id])
    end
  end
end
```

In general, you only need to test filtering when there is custom logic. Our schema validation test will ensure no filters are removed, guarded, changed operators, etc.

#### Sorting {#sorting}

```ruby
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
        expect(jsonapi_data.map(&:id)).to eq([
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
        expect(jsonapi_data.map(&:id)).to eq([
          employee2.id,
          employee1.id
        ])
      end
    end
  end
end
```

In general, you only need to test sorting when there is custom logic. Our schema validation test will ensure no sorts are removed, guarded or limited in direction.

#### Sideloading {#sideloading}

```ruby
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
      sl = jsonapi_data[0].sideload(:current_position)
      expect(sl.jsonapi_type).to eq('positions')
      expect(sl.id).to eq(pos2.id)
    end
  end
end
```

There is no need to test each attribute of the sideload - this should be tested in the [Resource Test](#resource-tests) of the sideloaded Resource.

In general, you only need to test sideloads when there is custom logic. Our schema validation test will ensure no sideloads are removed or associated to a different Resource.

### Writes {#writes}

The basic setup for write operations:

```ruby
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
```

Here `payload` is a [JSONAPI Resource Object](http://jsonapi.org/format/#crud).

#### Create {#create}

```ruby
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
```

`payload` starts as an empty Employee [Resource Object](http://jsonapi.org/format/#crud), asserting only that saving it creates an Employee. You'll likely want to add attributes here and ensure they are persisted correctly:

```ruby
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
```

##### Required Belongs To {#required-belongs-to}

Rails requires `belongs_to` associations by default. This means that if Employee `belongs_to :department`, the above tests will fail (we cannot create the Employee without associating it to Department).

You have 3 options here:

* Turn off this validation in test mode. Add `config.active_record.belongs_to_required_by_default = false` to `config/environments/test.rb`.
* Turn off the validation for this specific relationship: `belongs_to :department, optional: true`.
* Associate as part of the request.

We recommend the third option to preserve real-world end-to-end behavior:

```ruby
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
```

This ensures the Employee is created and associated to the given department.

#### Update {#update}

An update spec looks like the create spec, but finds an existing record instead of building a new one, and asserts the changed attribute rather than a changed count:

```ruby
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
```

> Note that this test will be pending by default when using the generator, as we require the attributes to be explicitly defined.

#### Destroy {#destroy}

Destroy specs drop the payload/instance-building entirely and just find and destroy the record, asserting the count decreases:

```ruby
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
```

#### Side Effects {#side-effects}

```ruby
it 'works' do
  # some assertion
  email = ActionMailer::Base.deliveries.last
  expect(email.subject).to eq('Welcome!')
end
```

It's common for write operations to cause side-effects, such as sending an email or updating an audit trail. It's recommended to test these *within the same "it" block* unless the logic gets particularly intense. Though "one expectation per test" works well for unit tests, integration tests can take longer to run and the performance penalty isn't worth it.

## API Tests {#api-tests}

There are five test files for each Resource:

* `spec/api/v1/employees/index_spec.rb`
* `spec/api/v1/employees/show_spec.rb`
* `spec/api/v1/employees/create_spec.rb`
* `spec/api/v1/employees/update_spec.rb`
* `spec/api/v1/employees/destroy_spec.rb`

### Reads {#api-reads}

#### #index {#index}

```ruby
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
      expect(jsonapi_data.map(&:jsonapi_type).uniq)
        .to match_array(['employees'])
      expect(jsonapi_data.map(&:id))
        .to match_array([employee1.id, employee2.id])
    end
  end
end
```

#### #show {#show}

Same shape as `#index`, but requests a single Employee by id and asserts against the singular `d` node instead of an array:

```ruby
subject(:make_request) do
  jsonapi_get "/api/v1/employees/#{employee.id}", params: params
end

describe 'basic fetch' do
  let!(:employee) { create(:employee) }

  it 'works' do
    expect(EmployeeResource).to receive(:find).and_call_original
    make_request
    expect(response.status).to eq(200)
    expect(jsonapi_data.jsonapi_type).to eq('employees')
    expect(jsonapi_data.id).to eq(employee.id)
  end
end
```

### Writes {#api-writes}

#### #create {#api-create}

```ruby
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
```

You probably only want to add attributes required to pass validation, here. We don't assert on attributes of the created record (save this for your Resource test). One easy way to do this is to pass randomized data from your factory:

```ruby
let(:payload) do
  {
    data: {
      type: 'employees',
      attributes: attributes_for(:employee)
    }
  }
end
```

See also: [Dealing with required belongs_to relationships](#required-belongs-to).

#### #update {#api-update}

Same as `#create`, but the payload finds an existing employee by `id` and the assertion checks that the record's attributes changed, rather than the count:

```ruby
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
```

We don't assert on specific attributes here - save that for your Resource test. Just like `#create`, you may want to use FactoryBot to generate randomized attributes:

```ruby
let(:payload) do
  {
    data: {
      id: employee.id.to_s,
      type: 'employees',
      attributes: attributes_for(:employee)
    }
  }
end
```

#### #destroy {#api-destroy}

```ruby
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
```

The response body is asserted to match the [JSONAPI specification for delete responses](http://jsonapi.org/format/#crud-deleting-responses-200): a 200 status with an empty `meta` object.

## Context {#context}

Occasionally you'll need to set context for tests. The most common scenario is authorization:

```ruby
attribute :salary, :integer, readable: :admin?

def admin?
  context.current_user.admin?
end
```

When using Rails, `context` is the controller associated to the request. We can manually set context in tests:

```ruby
let(:user) { double(admin?: true) }
let(:ctx) { double(current_user: user) }

it 'works' do
  Graphiti.with_context ctx do
    render
  end
  expect(jsonapi_data[0].salary).to eq(100_000)
end
```

## Schema Validation {#schema-validation}

Graphiti comes with built-in backwards-compatibility tests. We do this by comparing the current version of the schema with one previously checked-in.

These tests are added at the bottom of `spec/rails_helper.rb`:

```ruby
Graphiti::SpecHelpers::RSpec.schema!
```

Whenever you run tests, the schema check will *also* run. If we find any backwards-incompatibilities - attributes removed, types changed, default sort direction modified, etc - the schema test will fail with an output detailing all incompatibilities.

When the schema test succeeds, it will overwrite the existing schema file with the new schema. It will not do this on failure.

There are times when you want to accept an incompatibility and move on anyway. In this case, use `FORCE_SCHEMA`:

```bash
$ FORCE_SCHEMA=true bin/rspec
```

## Generators {#generators}

The [Resource generator](/concepts/resources#generators) will create both Resource and API tests for you. Use these as templates to implement your tests.

You can also run

```bash
$ rails generate graphiti:api_test RESOURCE [options]
```

For example

```bash
$ rails generate graphiti:api_test EmployeeResource -a index show
```

To generate only the API tests. This can be particularly helpful because API tests are mostly boilerplate that does not need to be manually edited. Pass the `-a` option to limit RESTful actions.

## Testing Spectrum {#testing-spectrum}

There's no single right level of test coverage. Teams vary. Our guides favor treating logicless configuration (filters, sorts, sideloads) as covered by Graphiti itself and by schema validation, adding Resource/API tests mainly where there's custom logic - but consider heavier coverage if you're doing a major upgrade or swapping datastores.

## Double-Testing Units {#double-testing-units}

A custom filter backed by an ActiveRecord scope can feel like it needs both a model unit test and a near-identical Resource integration test. Use [RSpec shared_context](https://relishapp.com/rspec/rspec-core/docs/example-groups/shared-context) to share the seed data between them, or, if the overhead isn't worth it, mark the scope `# @api private` and skip the unit test until the scope needs to be reused elsewhere.
