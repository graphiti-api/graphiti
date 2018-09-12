---
layout: page
---

<div markdown="1" class="toc col-md-3">
What is Graphiti?
==========

* 1 [Guiding Principles]
* 2 [Lifecycle of a Graphiti Request](#lifecycle-of-a-graphiti-request)

</div>

<div markdown="1" class="col-md-8">

## 2 Lifecycle of a Graphiti Request

<p align="center">
  <img width="100%" src="https://user-images.githubusercontent.com/55264/44479491-c3d3f100-a60e-11e8-90fb-e7654a94a2c9.png">
</p>

<br />

The key concept here is a **Resource**. [Resources](/guides/concepts/resources) sit between a Request and a Backend, defining how to ***query***, ***persist***, and ***serialize*** data. They are accessible through **[Endpoints](/guides/concepts/endpoints)**, which customize Resource behavior based on context.

<br />

<p align="center">
  <img width="80%" src="https://user-images.githubusercontent.com/55264/44619632-13592d80-a858-11e8-807e-36db566f86c6.png">
</p>

Each Resource is comprised of **Attributes**. Each Attribute corresponds to behavior for:

  * **Reading**: The fields rendered in the response, e.g. `{ "first_name": "Jane" }`
  * **Writing**: The fields accepted in the payload, e.g. a POST or PUT request.
  * **Filtering**: The fields we can query, e.g. `/employees?filter[first_name]=Jane`
  * **Sorting**: The fields we can sort on, e.g. `/employees?sort=age`

Each Attribute has a **Type**, which will be coerced and checked at runtime.

<p align="center">
  <img width="60%" src="https://user-images.githubusercontent.com/55264/44620523-df840500-a863-11e8-9a00-6eca2488b8ce.png">
</p>

A Resource does not mean "a database table", though the two have a lot in common and often match. A Resource is a generic interface wrapping a **Backend**. That Backend could be a relational database, a No-SQL database, or even a third-party service call. And you can use whichever client or ORM you'd like for a given Backend (`ActiveRecord`, `Sequel`, `Mongoid`, `Net::HTTP`, etc).

Resources define an interface for **querying** from and **persisting** to a given Backend. The generic, common, cross-Resource logic for connecting a Resource to a Backend is defined in an **Adapter**; individual Resources can override Adapter logic. The default adapter is `ActiveRecord` (`Graphiti::Adapters::ActiveRecord`).

From the raw backend results, the Resource builds **Models**, which hold
business logic. In other words you might **query** using `elasticsearch-ruby`, but return POROs as the result of that query. In the case of ActiveRecord, **Backend** and **Model** are the same thing.

Finally, these Models are *serialized* when we actually render a response. You'll still use `Rails`, `Sinatra`, or whatever-else to manage routing, HTTP codes, etc.

<p align="center">
  <img width="100%" src="https://user-images.githubusercontent.com/55264/44619631-13592d80-a858-11e8-9544-0809fb144cb2.png">
</p>

Critically, **each Resource can connect to other Resources**. This can occur through ***Sideloading*** ("fetch the employee, her positions, and the departments for those positions in a single request"), ***Sideposting*** ("*save* the employee and her positions/departments in a single request), and ***Links*** ("here's a URL to lazy-load positions in a separate request"). Because `Resource`s connect to each other, this is why we often refer to a Resource as a "node in the graph".

**Any logic used for fetching a single Resource can be re-used when fetching multiple Resources**. In other words, you can say "fetch me the Employee, and her last three Positions ordered by `created_at`". Applying query logic to nested levels of the graph is called **Deep Querying**.

Graphiti does not depend on Rails, but it *is* a first-class citizen.
Given the code:

{% highlight ruby %}
# config/routes.rb
resources :employees
{% endhighlight %}

{% highlight ruby %}
# app/controllers/employees_controller.rb
class EmployeesController < ApplicationController
  def index
    employees = EmployeeResource.all(params)
    respond_with(employees)
  end
end
{% endhighlight %}

{% highlight ruby %}
# app/models/employee.rb
class Employee < ApplicationRecord
end
{% endhighlight %}

{% highlight ruby %}
# app/resources/employee_resource.rb
class EmployeeResource < ApplicationResource
  attribute :name, :string
  attribute :age, :integer
end
{% endhighlight %}

We can now

* Fetch JSONAPI, Simple JSON, or XML
  * `/employees.jsonapi`
  * `/employees.json`
  * `/employees.xml`
* Paginate:
  * `/employees?page[size]=10&page[number]=2`
* Sort:
  * Ascending: `/employees?sort=age`
  * Descending: `/employees?sort=-age`
* Filter:
  * Case Insensitive: `/employees?filter[name]=jane doe`
  * Case Sensitive: `/employees?filter[name][eql]=Jane Doe`
  * Prefix: `/employees?filter[name][prefix]=graph`
  * Suffix: `/employees?filter[name][suffix]=rocks`
  * Contains: `/employees?filter[name][match]=iti`
  * Equal: `/employees?filter[age]=100`
  * Greater Than: `/employees?filter[age][gt]=100`
  * Greater Than or Equal To: `/employees?filter[age][gte]=100`
  * Less Than: `/employees?filter[age][lt]=100`
  * Less Than or Equal To: `/employees?filter[age][lte]=100`
* Only return specific fields:
  * `/employees?fields[employees]=name,age`
* Get total count:
  * `/employees?stats[total]=count`

To add a relationship:

{% highlight ruby %}
# app/models/employee.rb
has_many :positions
{% endhighlight %}

{% highlight ruby %}
# app/models/position.rb
class Position < ApplicationRecord
  belongs_to :employee
end
{% endhighlight %}

{% highlight ruby %}
# app/resources/employee_resource.rb
has_many :positions
{% endhighlight %}

{% highlight ruby %}
# app/resources/position_resource.rb
class PositionResource < ApplicationResource
  attribute :title, :string
  belongs_to :employee
end
{% endhighlight %}

<br />

We can now fetch Posts and Comments in a single request - ***including*** sorting the comments, filtering, fieldsets and everything else a [Resource](/guides/concepts/resources) supports.

<br />
