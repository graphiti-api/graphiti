---
title: 'Step 9'
---

### Step 9: Polymorphic Resources

> [View the Diff](https://github.com/graphiti-api/employee_directory/compare/step_8_polymorphic_belongs_to...step_9_polymorphic_resource)

In the last step, we covered polymorphic relationships: a single
relationship can point to many different Resources. Polymorphic
Resources are the same concept, without an association: a single
Resource can resolve to many different sub-Resources. It's a very similar
to [Single-Table Inheritance in ActiveRecord](https://api.rubyonrails.org/classes/ActiveRecord/Inheritance.html).

To illustrate this, we'll add a `tasks` table and corresponding `Task` superclass. Each record in this table will resolve to one of `Bug`, `Epic`, or `Feature`.

<table class="table table-small text-center">
  <thead>
    <tr>
      <th class="text-center">id</th>
      <th class="text-center">milestone_id</th>
      <th class="text-center">type</th>
      <th class="text-center">title</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>null</td>
      <td>Bug</td>
      <td>Incorrect Value!</td>
    </tr>
    <tr>
      <td>2</td>
      <td>null</td>
      <td>Feature</td>
      <td>Build great stuff!</td>
    </tr>
    <tr>
      <td>3</td>
      <td>1</td>
      <td>Epic</td>
      <td>Build TONS of great stuff!</td>
    </tr>
  </tbody>
</table>

Why not just stick with a single `Task` model? Because each of these types has specific behavior: only `Feature`s have a `points` attribute, and only `Epic`s have a `milestones` relationship.

### The Rails Stuff 🚂

Let's create our `Task` model:

```bash
$ bin/rails g model Task employee:belongs_to team:belongs_to type:string
title:string
$ bin/rails db:migrate
```

And create models to reflect our STI logic:

```ruby
# app/models/task.rb
class Task < ApplicationRecord
  TYPES = %w(Bug Feature Epic)

  belongs_to :team, optional: true
  belongs_to :employee, optional: true
end

# app/models/bug.rb
class Bug < Task
end

# app/models/feature.rb
class Feature < Task
end

# Only Epics have Milestones
# app/models/epic.rb
class Epic < Task
  has_many :milestones
end

# app/models/milestone.rb
class Milestone < ApplicationRecord
  belongs_to :epic
end
```

Add the association:

```ruby
# app/models/team.rb
has_many :tasks
has_many :bugs
has_many :features
has_many :epics

# app/models/employee.rb
has_many :tasks
has_many :bugs
has_many :features
has_many :epics
```

Finally [view the diff](https://github.com/graphiti-api/employee_directory/compare/step_8_polymorphic_belongs_to...step_9_polymorphic_resource) to edit your `seeds.rb` file.

### The Graphiti Stuff 🎨

Start by creating our Resource as normal:

```bash
$ bin/rails g graphiti:resource Task title:string
```

Now edit to support polymorphism and associations:

```ruby
class TaskResource < ApplicationResource
  self.polymorphic = %w(FeatureResource BugResource EpicResource)

  attribute :employee_id, :integer, only: [:filterable]
  attribute :team_id, :integer, only: [:filterable]
  attribute :title, :string

  belongs_to :employee
  belongs_to :team
end
```

The point of this was to show how responses could be specific to type,
so let's customize `Features`:

```ruby
class FeatureResource < TaskResource
  attribute :points, :integer do
    rand(20)
  end
end
```


Only Epics have milestones, but let's support those as well:

```bash
$ bin/rails g graphiti:resource Milestone name:string
```

```ruby
class MilestoneResource < ApplicationResource
  attribute :epic_id, :integer, only: [:filterable]
  attribute :name, :string

  # Customize the link to the Tasks endpoint, as we
  # didn't create an Epics endpoint
  belongs_to :epic do
    link do |milestone|
      helpers = Rails.application.routes.url_helpers
      helpers.task_url(milestone.epic_id)
    end
  end
end
```

#### Digging Deeper 🧐

We can now resolve `Tasks`, either as a relationship or through the `/tasks` endpoint directly. When `Task` is type `'Feature'` it will have an extra attribute of `points`. When it's an `Epic`, it will have an additional relationship `Milestone`.

Graphiti is smart enough to fetch the appropriate relationships. A hit
to `/tasks?include=milestones` will only query for milestones when the resulting `Task` records are `Epic`s.
