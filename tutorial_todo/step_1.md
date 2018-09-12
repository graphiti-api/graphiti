---
layout: page
---

Tutorial
==========

### Step 1: Basic Resource

We'll be working with a single database table, `employees`:

<table class="table">
  <thead>
    <tr>
      <th>id</th>
      <th>first_name</th>
      <th>last_name</th>
      <th>age</th>
      <th>created_at</th>
      <th>updated_at</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>Homer</td>
      <td>Simpson</td>
      <td>39</td>
      <td>2018-09-04 18:06:56</td>
      <td>2018-09-04 18:06:56</td>
    </tr>
    <tr>
      <td>2</td>
      <td>Waylon</td>
      <td>Smithers</td>
      <td>65</td>
      <td>2018-09-04 18:06:56</td>
      <td>2018-09-04 18:06:56</td>
    </tr>
    <tr>
      <td>3</td>
      <td>Monty</td>
      <td>Burns</td>
      <td>123</td>
      <td>2018-09-04 18:06:56</td>
      <td>2018-09-04 18:06:56</td>
    </tr>
  </tbody>
</table>

#### Rails

Use the built-in generator to create the database table
and corresponding `ActiveRecord` model:

{% highlight bash %}
$ bin/rails g model Employee first_name:string last_name:string age:integer
$ bin/rails db:migrate
{% endhighlight %}

Now let's seed some random development data, using [Faker](https://github.com/stympy/faker) (which was installed in [Step 0](/tutorial/step_0)):

{% highlight ruby %}
# db/seeds.rb
Employee.delete_all # Ensure the DB is cleaned each run

100.times do
  Employee.create! first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    age: rand(20..80)
end
{% endhighlight %}

Run this seed file with

{% highlight bash %}
$ bin/rails db:seed
{% endhighlight %}

#### Graphiti

Just like Rails, Graphiti has built-in generators. Let's generate
the corresponding Resource for our `Employee` model:

{% highlight bash %}
$ bin/rails g graphiti:resource Employee first_name:string last_name:string age:integer created_at:datetime updated_at:datetime
{% endhighlight %}

This generated a few things, but for now let's focus on
`EmployeeResource`:

{% highlight ruby %}
class EmployeeResource < ApplicationResource
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :age, :integer
  attribute :created_at, :datetime, writable: false
  attribute :updated_at, :datetime, writable: false
end
{% endhighlight %}

This code defined the [RESTful Resource](https://restful-api-design.readthedocs.io/en/latest/resources.html) we want our API to expose. Let's run our server and see what it does:

{% highlight bash %}
$ bin/rails s
{% endhighlight %}

Visit `localhost:3000/api/v1/employees`. You should see a [JSONAPI Response](http://jsonapi.org):

<br />

![jsonapi](https://user-images.githubusercontent.com/55264/45096386-710a3700-b0ee-11e8-8586-a7e342cca274.png)

<br />

If you find the payload a little intimidating, add `.json` to the URL for a more traditional response:

<br />

![json](https://user-images.githubusercontent.com/55264/45051465-2509b480-b052-11e8-9be4-3424ca611289.png)

<br />

There's `.xml`, too:

<br />

![xml](https://user-images.githubusercontent.com/55264/45051468-263ae180-b052-11e8-9a1d-b91e1caa1bbf.png)

<br />

These are all different **renderings** of the same `EmployeeResource`.

`Resources` are comprised of `Attribute`s:

{% highlight ruby %}
# app/resources/employee_resource.rb
attribute :first_name, :string
{% endhighlight %}

Each attribute defines behavior for:

* Reading (display)
* Writing
* Sorting
* Filtering
* Fieldsets

Let's start with simple display, turning `first_name` into all capital
letters:

{% highlight ruby %}
# app/resources/employee_resource.rb
attribute :first_name do
  # @object is your model instance
  @object.first_name.upcase
end
{% endhighlight %}

Which gives us:

![](https://user-images.githubusercontent.com/55264/45098021-25598c80-b0f2-11e8-965e-c245f91899ce.png)

<br />

This is the most important thing to understand about Resources: they are
just a collection of defaults, all of which can be overridden. In other
words:

{% highlight ruby %}
attribute :first_name

# is the same as

attribute :first_name do
  @object.first_name
end
{% endhighlight %}

We'll go into further Resource customizations over the course of this
tutorial. For now, let's just verify our out-of-the-box defaults:

* Sort by `first_name` ascending: `http://localhost:3000/api/v1/employees?sort=first_name`
* Sort by `first_name` descending: `http://localhost:3000/api/v1/employees?sort=-first_name`
* Return only `age` and `created_at` in the response: `http://localhost:3000/api/v1/employees?fields[employees]=age,created_at`
* Filter on `first_name`:
  * Case-insensitive: `http://localhost:3000/api/v1/employees?filter[first_name]=bob`
  * Case-sensitive: `http://locahost:3000/api/v1/employees?filter[first_name][eql]=Bob`
  * Prefix: `http://localhost:3000/api/v1/employees?filter[first_name][prefix]=b`
  * Suffix: `http://localhost:3000/api/v1/employees?filter[first_name][suffix]=ob`
  * Contains: `http://localhost:3000/api/v1/employees?filter[first_name][match]=o`
* Filter on `age`:
  * Equal: `http://localhost:3000/api/v1/employees?filter[age]=39`
  * Greater Than: `http://localhost:3000/api/v1/employees?filter[age][gt]=39`
  * Greater Than or Equal To: `http://localhost:3000/api/v1/employees?filter[age][gte]=39`
  * Less Than: `http://localhost:3000/api/v1/employees?filter[age][lt]=65`
  * Less Than or Equal To: `http://localhost:3000/api/v1/employees?filter[age][lte]=65`
* Paginate
  * 10 per page: `http://localhost:3000/api/v1/employees?page[size]=10`
  * 5 per page, third page:
    `http://localhost:3000/api/v1/employees?page[number]=3`

<!--TODO: Resource Concept Doc-->
<!--TODO: Attribute Concept Doc-->
<!--TODO: Endpoint Concept Doc-->
<!--TODO: Spec Concept Doc-->

Write operations are easiest to verify with integration tests, which
were created when we generated our Resource. Let's take a look at the
test for creating `Employee`s:

{% highlight ruby %}
# spec/api/v1/employees/create_spec.rb

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
            # ... your attrs here
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

<!--TODO API SPEC VS RESOURCE SPEC-->

This is an **API Spec**, which tests high-level end-to-end functionality. We
know that if our API receives a POST with the given payload, an
`Employee` will be created and a `201` response code will be returned.

API specs are high-level - often they won't be changed past this initial
boilerplate. For testing *logic*, use a **Resource Spec**. These
integration tests hit the database and run logic, but operate without a
specific request or response:

{% highlight ruby %}
# spec/api/v1/employees/create_spec.rb
RSpec.describe EmployeeResource, type: :resource do
  describe 'creating' do
    let(:payload) do
      {
        data: {
          type: 'employees',
          attributes: {
            first_name: 'Jane'
            last_name: 'Doe'
            age: 30
          }
        }
      }
    end

    let(:instance) do
      EmployeeResource.build(payload)
    end

    it 'works' do
      expect {
        expect(instance.save).to eq(true)
      }.to change { Employee.count }.by(1)
      employee = Employee.last
      expect(employee.first_name).to eq('Jane')
      expect(employee.last_name).to eq('Doe')
      expect(employee.age).to eq(30)
    end
  end
end
{% endhighlight %}

<!--TODO: ENDPOINT VERSUS RESOURCE-->

In other words: API specs test Endpoints (request, response, middleware,
etc), Resource specs test only the Resource (actual application logic).

Before we run these specs, we need to edit our [factories](https://github.com/thoughtbot/factory_bot) to ensure
dynamic, randomized data. Let's change this:

{% highlight ruby %}
# spec/factories/employee.rb

FactoryBot.define do
  factory :employee do
    first_name "MyString"
    last_name "MyString"
    age 1
  end
end
{% endhighlight %}

To

{% highlight ruby %}
# spec/factories/employee.rb

FactoryBot.define do
  factory :employee do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    age { rand(20.80) }
  end
end
{% endhighlight %}

Now undo the changes to `first_name`, and run the generated specs:

{% highlight bash %}
$ bin/rspec
{% endhighlight %}

You'll see 11 tests pass, with 3 pending. One of the pending specs was
autogenerated by rails - you can delete `spec/models/employee_spec.rb`
for now.

That leaves us with two "update" specs. These are marked pending so you
can manage the data yourself. Follow the comments in these specs to add
attributes and get them passing.

<!--TODO TESTING GUIDE-->

<div class="clearfix">
  <h2 id="next">
    <a href="/tutorial/step_2">
      NEXT:
      <small>Step 2: Has Many</small>
      &raquo;
    </a>
  </h2>
</div>
