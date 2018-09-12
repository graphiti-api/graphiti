---
layout: page
---

<div markdown="1" class="toc col-md-3">
Backends and Models
==========

* 1 [Overview](#overview)
  * [ActiveRecord](#activerecord)
  * [Model Requirements](#model-requirements)
  * [Validations](#validations)
* 2 [Model Implementations](#model-implementations)
  * [PORO](#poro)
  * [ActiveModel::Model](#activemodelmodel)
  * [Dry::Struct](#drystruct)
* 3 [Model Tips](#model-tips)
  * [ID-less Models](#id-less-models)
</div>

<div markdown="1" class="col-md-8">
## 1 Overview

A Resource *queries* and *persists* to a **Backend**. It returns
**Models** from the Backend response, which get *serialized*. In this way, it is
an implementation of the [Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html).

This is best illustrated in code. Let's say we have a Backend class
that accepts a hash of options to perform a query:

{% highlight ruby %}
results = Backend.query \
  conditions: { name: 'Jane' },
  sort: { created_at: :asc }

results # [{ id: 1, name: 'Jane', rank: 83 }, ...]
{% endhighlight %}

And a PORO Model that encapsulates those results, holding business logic:

{% highlight ruby %}
class Employee
  attr_accessor :id, :name, :rank

  def initialize(attrs = {})
    attrs.each_pair { |k, v| send(:"#{k}=", v) }
  end

  def exemplary?
    rank > 80
  end
end
{% endhighlight %}

Meaning that normally, our code would look something like:

{% highlight ruby %}
results = Backend.query(params)
employees = results.map { |r| Employee.new(r) }
employees.map(&:exemplary?) # => [true, false, ...]
{% endhighlight %}

Let's wire-up that same code to a Resource:

{% highlight ruby %}
class EmployeeResource < ApplicationResource
  # We'll be coding the logic manually
  self.adapter = Graphiti::Adapters::Null

  attribute :name, :string

  # The blank scope we start with
  def base_scope
    { conditions: {}, sort: {}  }
  end

  # Merge filters into the hash based on request params
  filter :name do
    eq do |scope, value|
      scope[:conditions].merge!(c)
    end
  end

  # Set sort based on request params
  sort :name do |scope, direction|
    scope[:sort] = { name: direction }
  end

  # 'scope' here is out hash
  # We pass it to Backend.query, and return Models
  def resolve(scope)
    results = Backend.query(scope)
    results.map { |r| Employee.new(r) }
  end
end
{% endhighlight %}

As you see above, a **scope** can be anything from an
`ActiveRecord::Relation` to a plain ruby hash. We want to adjust
*something* based on the request parameters and pass it to our backend.
From the raw backend results, we can instantiate Models.

Of course, most Backends have predictable and consistent interfaces. It
would be a pain to manually write this code for every Resource. So
instead we could build an **Adapter** to DRY this logic:

{% highlight ruby %}
class EmployeeResource < ApplicationResource
  self.adapter = BackendAdapter
  attribute :name, :string
end
{% endhighlight %}

In summary: a Resource builds a query that is sent to a Backend. The
backend executes the query, and we instantiate Models from the raw
results.

### 1.1 ActiveRecord

From the [ActiveRecord Guides](https://guides.rubyonrails.org/active_record_basics.html#the-active-record-pattern):

> *[Active Record was described by Martin Fowler](https://www.martinfowler.com/eaaCatalog/activeRecord.html) in his book Patterns of Enterprise Application Architecture. In Active Record, objects carry both persistent data and behavior which operates on that data. Active Record takes the opinion that ensuring data access logic as part of the object will educate users of that object on how to write to and read from the database.*

In other words, ActiveRecord is **combines** a Backend and Model.
Opinions on this [vary](https://blog.lelonek.me/why-is-your-rails-application-still-coupled-to-activerecord-efe34d657c91),
but Graphiti supports either approach: we can separate data and business layers, or
combine them. See the ActiveRecord doppleganger of the above at our
[Resource cheatsheet]({{site.github.url}}/cheatsheet).

### 1.2 Model Requirements

The only hard requirement of a Model is that it responds to `id`. We use
`model.id` to determine uniqueness when rendering a JSONAPI response.
**You will get incorrect results if `model.id` is not unique**.

Models should also respond to any readable attributes. Remember that:

{% highlight ruby %}
attribute :name, :string
{% endhighlight %}

Is the same as

{% highlight ruby %}
# @object is your Model instance
attribute :name, :string do
  @object.name
end
{% endhighlight %}

If your Model does not respond to an attribute name, either pass a block to `attribute` or
look into [aliasing](https://blog.bigbinary.com/2012/01/08/alias-vs-alias-method.html).

#### 1.2.1 Validations

Graphiti will perform validations on your models during write requests,
returning a [JSONAPI-compliant errors payload](http://jsonapi.org/format/#errors).
To get this functionality, your model must adhere to the
[ActiveModel::Validations API](https://api.rubyonrails.org/classes/ActiveModel/Validations.html):

{% highlight ruby %}
model.valid?
object.errors.messages.each_pair { ... }
{% endhighlight %}

It is highly recommended to mix in:

{% highlight ruby %}
class Employee
  include ActiveModel::Validations
end
{% endhighlight %}

## 2 Model Implementations

Because our default is ActiveRecord, it may be unclear what other Models
look like. Graphiti itself has no opinion about your Model layer, but
below are a few examples.

### 2.1 PORO

{% highlight ruby %}
class Employee
  attr_accessor :id,
    :first_name,
    :last_name,
    :age

  def initialize(attrs = {})
    attrs.each_pair { |k,v| send(:"#{k}=", v) }
  end
end
{% endhighlight %}

This is a common ruby example. `attr_accessor` defines getters and
setters for our properties, and we assign those properties in the
constructor:

{% highlight ruby %}
e = Employee.new(id: 1, first_name: 'Jane')
e.first_name # => 'Jane'
{% endhighlight %}

### 2.2 ActiveModel::Model

A simple abstraction of the above is [ActiveModel::Model](https://api.rubyonrails.org/classes/ActiveModel/Model.html):

{% highlight ruby %}
class Employee
  include ActiveModel::Model

  attr_accessor :id,
    :first_name,
    :last_name,
    :age
end
{% endhighlight %}

{% highlight ruby %}
e = Employee.new(id: 1, first_name: 'Jane')
e.first_name # => 'Jane'
{% endhighlight %}

### 2.3 Dry::Struct

[dry-types](https://dry-rb.org/gems/dry-types) is a dependency of Graphiti and successor to the popular [Virtus](https://github.com/solnic/virtus).

{% highlight ruby %}
module Types
  include Dry::Types.module
end

class Employee < Dry::Struct
  attribute :id, Types::Integer
  attribute :first_name, Types::String
  attribute :last_name, Types::Integer
  attribute :age, Types::Integer
end
{% endhighlight %}

{% highlight ruby %}
e = Employee.new(id: 1, first_name: 'Jane')
e.first_name # => 'Jane'
{% endhighlight %}

## 3 Model Tips

### ID-less Models

If your Model does not have an `id` property, using a random UUID is
perfectly acceptable:

{% highlight ruby %}
def id
  @id ||= SecureRandom.uuid
end
{% endhighlight %}
