---
layout: page
---

Resource Cheatsheet
===================

This is an expanded version of what's "under the hood" of a default
Resource:

{% highlight ruby %}
class EmployeeResource < ApplicationRecord
  self.model = Employee

  # JSONAPI type
  # http://jsonapi.org/format/#document-resource-identifier-objects
  self.type = :employees

  # Expanded version
  attribute :name, :string,
    readable: self.attributes_sortable_by_default,
    writable: self.attributes_sortable_by_default,
    sortable: self.attributes_sortable_by_default,
    filterable: self.attributes_sortable_by_default

  # Alter display
  # @object is your model instance
  attribute :name, :string do
    @object.name.upcase
  end

  # Default nil
  self.default_sort = [{ name: :desc }]
  # Default 10
  self.default_per_page = 10

  # Custom sort
  # sort :name, :string if no attribute defined
  sort :name do |scope, dir|
    scope.order(name: dir)
  end

  # Custom Filter
  # filter :name, :string if no attribute defined
  filter :name do
    # All of the operators here have not_ equivalents, e.q. not_eq
    # imagine ".where.not" instead of ".where"

    eq do |scope, value|
      scope.where("lower(name) IN ?", value.map(&:downcase))
    end

    eql do |scope, value|
      scope.where(name: value)
    end

    prefix do |scope, value|
      value.each do |v|
        scope = scope.where('lower(name) LIKE ?', "#{v.downcase}%")
      end
      scope
    end

    suffix do |scope, value|
      value.each do |v|
        scope = scope.where('lower(name) LIKE ?', "%#{v.downcase}")
      end
      scope
    end

    match do |scope, value|
      value.each do |v|
        scope = scope.where('lower(name) LIKE ?', "%#{v.downcase}%")
      end
      scope
    end
  end

  # Operators for integer, float, datetime, etc
  filter :age, :integer do
    eq do |scope, value|
      scope.where(age: value)
    end

    gt do |scope, value|
      value.each do |v|
        scope = scope.where('age > ?', v)
      end
      scope
    end

    gte do |scope, value|
      value.each do |v|
        scope = scope.where('age >= ?', v)
      end
      scope
    end

    lt do |scope, value|
      value.each do |v|
        scope = scope.where('age < ?', v)
      end
      scope
    end

    lte do |scope, value|
      value.each do |v|
        scope = scope.where('age <= ?', v)
      end
      scope
    end
  end

  # Must execute query and return an array of Model instances
  def resolve(scope)
    scope.to_a
  end

  def create(attributes)
    employee = Employee.create(attributes)
    employee.save
    employee
  end

  def update(attributes)
    employee = self.class.find(id: attributes.delete(:id))
    employee.update_attributes(attributes)
    employee
  end

  def destroy(id)
    employee = self.class.find(id: attributes.delete(:id))
    employee.destroy
    employee
  end
end
{% endhighlight %}
