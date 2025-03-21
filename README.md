#### Graphiti

[![CI](https://github.com/graphiti-api/graphiti/actions/workflows/ci.yml/badge.svg)](https://github.com/graphiti-api/graphiti/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/graphiti.svg)](https://badge.fury.io/rb/graphiti)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![semantic-release: angular](https://img.shields.io/badge/semantic--release-angular-e10079?logo=semantic-release)](https://github.com/semantic-release/semantic-release)


[![discord](https://img.shields.io/badge/community-discord-8A2BE2?logo=discord)](https://discord.gg/wgqkMBsSRV)
[![guides](https://img.shields.io/badge/guides-https://www.graphiti.dev-F565A5)](https://www.graphiti.dev)



<img align="right" src="https://user-images.githubusercontent.com/55264/54884141-c10ada00-4e43-11e9-866b-e3c01e33a7c7.png" alt="Graphiti logo" width="150px" />
Graphiti is a resource-oriented framework that sits on top of your models (usually ActiveRecord) and exposes them via a JSON:API-compliant interface. It abstracts common concerns like serialization, filtering, sorting, pagination, and sideloading relationships, so you can build powerful APIs with minimal boilerplate. By defining resources instead of controllers and serializers, Graphiti helps you keep your API logic organized, consistent, and easy to maintain.


#### Examples 
Here's an example resource from the [example app](https://github.com/graphiti-api/employee_directory/) just to give you a taste of the possibilities. 


```ruby
class EmployeeResource < ApplicationResource
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :age, :integer
  attribute :created_at, :datetime, writable: false
  attribute :updated_at, :datetime, writable: false
  attribute :title, :string, only: [:filterable, :sortable]

  has_many :positions
  has_many :tasks
  many_to_many :teams
  polymorphic_has_many :notes, as: :notable
  has_one :current_position, resource: PositionResource do
    params do |hash|
      hash[:filter][:current] = true
    end
  end

  filter :title, only: [:eq] do
    eq do |scope, value|
      scope.joins(:current_position).merge(Position.where(title: value))
    end
  end

  sort :title do |scope, value|
    scope.joins(:current_position).merge(Position.order(title: value))
  end

  sort :department_name, :string do |scope, value|
    scope.joins(current_position: :department)
      .merge(Department.order(name: value))
  end
end
```

A pretty boilerplate controller that just interfaces with the resource
```ruby
class EmployeesController < ApplicationController
  def index
    employees = EmployeeResource.all(params)
    respond_with(employees)
  end

  def show
    employee = EmployeeResource.find(params)
    respond_with(employee)
  end

  def create
    employee = EmployeeResource.build(params)

    if employee.save
      render jsonapi: employee, status: 201
    else
      render jsonapi_errors: employee
    end
  end

  def update
    employee = EmployeeResource.find(params)

    if employee.update_attributes
      render jsonapi: employee
    else
      render jsonapi_errors: employee
    end
  end

  def destroy
    employee = EmployeeResource.find(params)

    if employee.destroy
      render jsonapi: { meta: {} }, status: 200
    else
      render jsonapi_errors: employee
    end
  end
end
```
  
</details>


Now you can query your endpoints simply and powerfully, like: 



Request:
```http://localhost:3000/api/v1/employees?filter[title][eq]=Future Government Administrator&filter[age][lt]=40```

<details>
<summary>JSON-API response</summary>

```json
{
  "data": [
    {
      "id": "1",
      "type": "employees",
      "attributes": {
        "first_name": "Quinn",
        "last_name": "Homenick",
        "age": 36,
        "created_at": "2025-03-21T23:04:40+00:00",
        "updated_at": "2025-03-21T23:04:40+00:00"
      },
      "relationships": {
        "positions": {
          "links": {
            "related": "/api/v1/positions?filter[employee_id]=1"
          },
          "data": [
            {
              "type": "positions",
              "id": "1"
            },
            {
              "type": "positions",
              "id": "2"
            }
          ]
        },
        "tasks": {
          "links": {
            "related": "/api/v1/tasks?filter[employee_id]=1"
          }
        },
        "teams": {
          "links": {
            "related": "/api/v1/teams?filter[employee_id]=1"
          }
        },
        "notes": {
          "links": {
            "related": "/api/v1/notes?filter[notable_id]=1&filter[notable_type][eql]=Employee"
          }
        },
        "current_position": {
          "links": {
            "related": "/api/v1/positions?filter[current]=true&filter[employee_id]=1"
          },
          "data": {
            "type": "positions",
            "id": "1"
          }
        }
      }
    }
  ],
  "included": [
    {
      "id": "1",
      "type": "positions",
      "attributes": {
        "title": "Future Government Administrator",
        "active": true
      },
      "relationships": {
        "employee": {
          "links": {
            "related": "/api/v1/employees/1"
          }
        },
        "department": {
          "links": {
            "related": "/api/v1/departments/3"
          }
        }
      }
    },
    {
      "id": "2",
      "type": "positions",
      "attributes": {
        "title": "Manufacturing Specialist",
        "active": false
      },
      "relationships": {
        "employee": {
          "links": {
            "related": "/api/v1/employees/1"
          }
        },
        "department": {
          "links": {
            "related": "/api/v1/departments/2"
          }
        }
      }
    }
  ],
  "meta": {}
}
```

</details>



[Graphiti Guides](https://www.graphiti.dev/guides/)

[Join the Discord](https://discord.gg/wgqkMBsSRV)




