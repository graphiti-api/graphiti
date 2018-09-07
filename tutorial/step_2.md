---
layout: page
---

Tutorial
==========

### Step 2: Has Many

We'll be adding the database table `positions`:

<table class="table text-center">
  <thead>
    <tr>
      <th class="text-center">id</th>
      <th class="text-center">employee_id</th>
      <th class="text-center">title</th>
      <th class="text-center">active</th>
      <th class="text-center">historical_index</th>
      <th class="text-center">created_at</th>
      <th class="text-center">updated_at</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>900</td>
      <td>Engineer</td>
      <td>true</td>
      <td>1</td>
      <td>2018-09-04 18:06:56</td>
      <td>2018-09-04 18:06:56</td>
    </tr>
    <tr>
      <td>2</td>
      <td>900</td>
      <td>Intern</td>
      <td>true</td>
      <td>2</td>
      <td>2018-09-04 18:06:56</td>
      <td>2018-09-04 18:06:56</td>
    </tr>
    <tr>
      <td>3</td>
      <td>800</td>
      <td>Manager</td>
      <td>true</td>
      <td>1</td>
      <td>2018-09-04 18:06:56</td>
      <td>2018-09-04 18:06:56</td>
    </tr>
  </tbody>
</table>

Because this table tracks all historical positions, we have the
`historical_index` column. This tells the order the employee moved
through each position, where `1` is most recent.

#### Rails

Generate the `Position` model:

{% highlight bash %}
$ bin/rails g model Position title:string active:boolean historical_index:integer employee:belongs_to
{% endhighlight %}

Update the `Employee` model with the association, too:

{% highlight ruby %}
# app/models/employee.rb
has_many :positions
{% endhighlight %}

And update our seed data:

{% highlight ruby %}
# db/seeds.rb
[Employee, Position].each(&:delete_all)

100.times do
  employee = Employee.create! first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    age: rand(20..80)

  (1..2).each do |i|
    employee.positions.create! title: Faker::Job.title,
      historical_index: i,
      active: i == 1
  end
end
{% endhighlight %}

{% highlight bash %}
$ bin/rails db:seed
{% endhighlight %}

When running our tests, let's make sure the `historical_index` column
reflects the order we created the positions. This code recalculates
everything after a record is saved:

{% highlight ruby %}
# spec/factories/position.rb
FactoryBot.define do
  factory :position do
    employee

    title { Faker::Job.title }

    after(:create) do |position|
      unless position.historical_index
        scope = Position
          .where(employee_id: position.employee.id)
          .order(created_at: :desc)
        scope.each_with_index do |p, index|
          p.update_attribute(:historical_index, index + 1)
        end
      end
    end
  end
end
{% endhighlight %}

#### Graphiti

Let's start by running the same command as before to create
`PositionResource`:

{% highlight bash %}
$ bin/rails g graphiti:resource Position title:string active:boolean
{% endhighlight %}

And we'll need to add the associations:

{% highlight ruby %}
# app/resources/employee_resource.rb
has_many :positions
{% endhighlight %}

This allows loading employees and their positions in a single request:

`/api/v1/employees?include=positions`

Now let's add the reverse: starting with positions, and loading
employees:

{% highlight ruby %}
# app/resources/position_resource.rb
belongs_to :employee
{% endhighlight %}

`/api/v1/positions?include=employee`

{% comment %}TODO link the Link{% endcomment %}

But what if we wanted to first load only the `Employee`, and lazy-load
`Position`s in a separate request? In other words, a Link from an
`Employee` to their `Position`s would look like:

`/api/v1/positions?filter[employee_id]=123`

And so we should add the corresponding filter if we want to enable this
functionality:

{% highlight ruby %}
attribute :employee_id, :integer, only: [:filterable]
{% endhighlight %}

> Note: this is the same as `filter :employee_id, :integer`, but it's a
> best practice to call out these "foreign keys" alongside other
> attributes.

We can now traverse `Employee`s and `Positions` via Links:

{% comment %}TODO GIF{% endcomment %}

Let's revisit the `historical_index` column. For now, let's
treat this as an implementation detail that the API should not expose -
let's say we want to support sorting on this attribute but nothing else:

{% highlight ruby %}
attribute :historical_index, :integer, only: [:sortable]
{% endhighlight %}

We're almost done, but if you run your tests you'll see two outstanding
errors. This is because [Rails 5 belongs_to associations are required by
default](https://blog.bigbinary.com/2016/02/15/rails-5-makes-belong-to-association-required-by-default.html). We can't save a `Position` without its corresponding `Employee`.

We can solve this in three ways:

* Turn this off globally, with [config.active_record.belongs_to_required_by_default](https://edgeguides.rubyonrails.org/configuring.html#configuring-active-record). You may want to do this in test-mode only.
* Turn this off for the specific association: `belongs_to :employee,
optional: true`.
* Associate an `Employee` as part of the API request.

We'll opt for the last option. Look at
`spec/resources/position/writes_spec.rb`:

{% highlight ruby %}
RSpec.describe PositionResource, type: :resource do
  describe 'creating' do
    let(:payload) do
      {
        data: {
          type: 'positions',
          attributes: { }
        }
      }
    end

    let(:instance) do
      PositionResource.build(payload)
    end

    it 'works' do
      expect {
        expect(instance.save).to eq(true)
      }.to change { Position.count }.by(1)
    end
  end
end
{% endhighlight %}

Let's associate an `Employee`. Start by seeding the data:

{% highlight ruby %}
let!(:employee) { create(:employee) }
{% endhighlight %}

And associate via `relationships`:

{% highlight ruby %}
let(:payload) do
  {
    data: {
      type: 'positions',
      attributes: { },
      relationships: {
        employee: {
          data: employee.id.to_s,
          type: 'employees'
        }
      }
    }
  }
end
{% endhighlight %}

This will associate the `Position` to the `Employee` as part of the
creation process. The test should now pass - make the same change to
`spec/api/v1/positions/create_spec.rb` to get a fully-passing test
suite.
