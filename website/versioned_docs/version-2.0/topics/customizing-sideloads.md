---
title: 'Customizing Sideloads'
---

# Customizing Sideloads
> [See the code in our sample app](https://github.com/graphiti-api/employee_directory/commit/e5dbb24b7e5853a9f39aed455a5d318d303df37e)

This cookbook will help you understand sideloading. It would be great to
live in a world where everything follows default ActiveRecord table
conventions, but in my experience this is rarely the case. From legacy
code to alternate datastores, we need to think in Real World terms.

Our [Employee Directory](https://github.com/graphiti-api/employee_directory) sample application
has a clean schema - let's screw with it. Let's say `Department` has a column called `watcher_emails`, which is an array of strings. We want to sideload `Department > Watchers`. Though the *relationship* is called `watchers`, these will be `Employee` records.

Let's start by adding a spec:

```ruby
# spec/resources/department/reads_spec.rb

describe 'sideloading' do
  describe 'watchers' do
    let!(:employee1) { create(:employee) }
    let!(:employee2) { create(:employee) }
    let!(:employee3) { create(:employee) }
    let!(:department) do
      create :department,
        watcher_emails: [employee1.email, employee3.email]
    end

    before do
      params[:include] = 'watchers'
    end

    it 'sideloads employees via watcher_emails' do
      render
      sl = d[0].sideload(:watchers)
      expect(sl.map(&:id)).to eq([employee1.id, employee3.id])
      expect(sl.map(&:jsonapi_type).uniq).to eq(['employees'])
    end
  end
end
```

Add the relationship:

```ruby
# app/resources/department_resource.rb
has_many :watchers, resource: EmployeeResource
```

Run the test and you'll get this error:

```error
Graphiti::Errors::AttributeError:
  EmployeeResource: Tried to filter on attribute :department_id, but could not find an attribute with that name.
```

How would we track down this error? Well, we know Resources connect
together with [Links](/concepts/links). Let's
take a look at the query parameters that would be used to connect these
two Resources:

```ruby
has_many :watchers, resource: EmployeeResource do
  params do |hash, departments|
    binding.pry
  end
end
```

> Note - we're using [pry](https://github.com/pry/pry) to debug here.

The value of `hash` here is:

```ruby
{ filter: { department_id: "1" } }
```

Which makes sense. If we say `has_many :things`, by default we expect `Thing` to have a `department_id` we can query.

That's not our case, though. Instead, let's customize those parameters
to fit our use case:

```ruby
params do |hash, departments|
  emails = departments.map(&:watcher_emails).flatten
  hash[:filter] = { email: emails }
end
```

Instead of querying by `department_id`, we need to query by `email`. And
the value we pass in will be an array of email addresses

We'd need to add an `email` filter to `EmployeeResource` to make this
work. This gets us ***querying*** correctly, but there's another error:

```error
undefined method `department_id' for #<Employee:0x00007f9652ae6d80>
```

Here's the thing to keep in mind: let's say our request was
`/departments?include=watchers`. We queried all the data, and we now have an array of `Department`s and an array of `Employee`s. Now we need
to specify which employees should be assigned as watchers of which
department.

Let's write that code manually:

```ruby
has_many :watchers, resource: EmployeeResource do
  # ... code ...
  assign do |departments, employees|
    departments.each do |d|
      d.watchers = employees.select do |e|
        e.email.in?(d.watcher_emails)
      end
    end
  end
end
```

We're selecting all relevant `Employee`s for a given `Department` by checking the array of `watcher_emails`.

This code can be tightened up a little with `assign_each` (recommended).
This way we don't have to iterate departments or worry about the
assignment ourselves:

```ruby
has_many :watchers, resource: EmployeeResource do
  # ... code ...

  assign_each do |department, employees|
    employees.select { |e| e.email.in?(d.watcher_emails) }
  end
end
```

We're using `#select` to return an array of relevant `Employee`s. If this was a `belongs_to` or `has_one` relationship, we'd probably want to use `#find` to return a single `Employee`.

OK there's *one last error*:

```error
undefined method `watchers=' for #<Department:0x00007feb625a7468>
```

This one is simple - the `assign` function will call your Adapter's assignment logic, which by default will be a simple `department.watchers
= relevant_employees`. That means we need to add a getter/setter for
this property:

```ruby
# app/models/department.rb
attr_accessor :watchers
```

And we're done! The test should now pass. [Check out the working code
here](https://github.com/graphiti-api/employee_directory/tree/customize_sideloads_cookbook).
