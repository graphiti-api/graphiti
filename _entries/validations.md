---
sectionid: validations
sectionclass: h2
title: Validations
parent-id: writes
number: 10
---

If our model has a validation error, we need to render a [JSON API Error
Object](http://jsonapi.org/format/#errors). You can just use
`render_errors_for` and forget about it:

```ruby
def create
  employee = Employee.new(employee_params)

  if employee.save
    render_ams(employee)
  else
    render_errors_for(employee)
  end
end
```

Would output a `422` response code with something like:

```ruby
{
  errors: [
    {
      code: 'unprocessable_entity',
      status: '422',
      title: 'Validation Error',
      detail: "Name can't be blank",
      source: { pointer: '/data/attributes/name' },
      meta: {
        attribute: :name,
        message: "can't be blank"
      }
    }
  ]
}
```
