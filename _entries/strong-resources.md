---
sectionid: strong_resources
sectionclass: h2
title: Strong Resources
parent-id: writes
number: 11
---

At this point we **could** use regular ol' [strong_parameters](https://github.com/rails/strong_parameters). That would work. However, two things eventually crop up making this a pain point:

* You end up typing essentially the same stuff when writing your
  [swagger](http://swagger.io) documentation, which violates the DRY
principle and leads to code and documentation getting out of sync.
* If your API endpoints accept nested resources, you end up typing the
  same nested resource attributes across multiple controllers,
inevitably adding an attribute it one place but forgetting it in others.

Enter Strong Resources - DRY strong parameters! Instead of code like
this:

```ruby
def employee_params
  params.require(:employee).permit \
    :name,
    :email,
    department_attributes: [:name]
end
```

Write this:

```ruby
# config/initializers/strong_resources.rb
StrongResources.configure do
  strong_resource :employee do
    attribute :name, :string
    attribute :email, :string
  end

  strong_resource :department do
    attribute :name, :string
  end
end

# app/controllers/employees_controller.rb
class EmployeesController < ApplicationController
  jsonapi { ...code... }

  strong_resource :employee do
    belongs_to :department
  end
end

# app/controllers/departments_controller.rb
class DepartmentsController < ApplicationController
  strong_resource :department
end
```

We're defining our resource payloads only once, all in
`config/initializers/strong_resources`, then referencing those payloads
in each controller. We'll be able to reference this same metadata when
auto-documenting our API in swagger.

Since this gem uses [stronger_parameters](https://github.com/zendesk/stronger_parameters) underneath the hood, we also get free type checking and type casting. For instance passing a `Time` for the `name` attribute would raise `StrongerParameters::InvalidParameter`.

You can also register custom types:

```ruby
Parameters = ActionController::Parameters
strong_param :department_enum,
  swagger: :string, # the corresponding swagger type
  type: Parameters.enum('Safety', 'Sales', 'Accounting')

strong_resource :department do
  attribute :name, :department_enum
end
```

Would throw a `StrongerParameters::InvalidParameter` when passing a
department name that is not 'Safety', 'Sales', or 'Accounting'.

Attributes can be conditional as well:

```ruby
strong_resource :employee do
  attribute :salary, :integer, if: ->(controller) {
    controller.current_user.admin?
  }
end
```

{::options parse_block_html="true" /}
<div class='note info'>
###### Further Reading
  <div class='note-content'>
  To learn more about strong resources, check out the
  [strong_resources](https://github.com/jsonapi-suite/strong_resources)
  libary as well as [stronger_parameters](https://github.com/zendesk/stronger_parameters), the library it uses under the covers.
  </div>
</div>
<div style="height: 7rem" />
