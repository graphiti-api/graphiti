---
layout: page
---

Tutorial
==========

### Step 3: Belongs To

We'll be adding the database table `departments`:

<table class="table text-center">
  <thead>
    <tr>
      <th class="text-center">id</th>
      <th class="text-center">name</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>Engineering</td>
    </tr>
    <tr>
      <td>2</td>
      <td>Safety</td>
    </tr>
    <tr>
      <td>3</td>
      <td>QA</td>
    </tr>
  </tbody>
</table>

We'll also be adding a `department_id:integer` foreign key column to
the `positions` table.

#### Rails

Generate the `Department` model:

{% highlight bash %}
$ bin/rails g model Department name:string
{% endhighlight %}

To add the foreign key to `positions`:

{% highlight bash %}
$ bin/rails g migration add_department_id_to_positions
{% endhighlight %}

{% highlight ruby %}
class AddDepartmentIdToPositions < ActiveRecord::Migration[5.2]
  def change
    add_foreign_key :positions, :departments
  end
end
{% endhighlight %}

Update the database:

{% highlight bash %}
$ bin/rails db:migrate
{% endhighlight %}

Update our seed file:

{% highlight ruby %}
[Employee, Position, Department].each(&:delete_all)

engineering = Department.create! name: 'Engineering'
safety = Department.create! name: 'Safety'
qa = Department.create! name: 'QA'
departments = [engineering, safety, qa]

100.times do
  employee = Employee.create! first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    age: rand(20..80)

  (1..2).each do |i|
    employee.positions.create! title: Faker::Job.title,
      historical_index: i,
      active: i == 1,
      department: departments.sample
  end
end
{% endhighlight %}

Make sure to update `spec/factories/departments` with randomized
data. Then, since this is also a required relationship, update
`spec/factories/positions.rb` to always seed a department when we ask to
create a position:

{% highlight ruby %}
factory :position do
  employee
  department

  # ... code ...
end
{% endhighlight %}

#### Graphiti

You should be used to this by now:

{% highlight bash %}
bin/rails g graphiti:resource Department name:string
{% endhighlight %}

Add the associations

{% highlight ruby %}
# app/resources/position_resource.rb
belongs_to :department
{% endhighlight %}

{% highlight ruby %}
# app/resources/department_resource.rb
has_many :positions
{% endhighlight %}

Remember the relevant filter, if desired:

{% highlight ruby %}
# app/resources/position_resource.rb
attribute :department_id, :integer, only: [:filterable]
{% endhighlight %}

And review the end of [Step 2](/tutorial/step_2) to get all your specs
passing (add the department to the request payload). Practice makes perfect!
