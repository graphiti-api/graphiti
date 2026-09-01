require "pp"
require "active_record"
require "kaminari"
require "graphiti"
require "./seeds"

class ApplicationResource < Graphiti::Resource
  self.abstract_class = true
  self.adapter = Graphiti::Adapters::ActiveRecord
  self.autolink = false
end

class EmployeeResource < ApplicationResource
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :age, :integer

  has_many :positions
end

class PositionResource < ApplicationResource
  attribute :employee_id, :integer, only: [:filterable]
  attribute :department_id, :integer, only: [:filterable]
  attribute :title, :string

  belongs_to :department
end

class DepartmentResource < ApplicationResource
  attribute :name, :string
end

Graphiti.setup!

employees = EmployeeResource.all({
  sort: "-id",
  filter: {age: {gt: 30}},
  page: {size: 10, number: 1},
  include: "positions.department"
})

employees.each do |e|
  puts "#{e.first_name} | #{e.positions[0].title} | #{e.positions[0].department.name}"
end

pp JSON.parse(employees.to_jsonapi)
puts "\n\n"
pp JSON.parse(employees.to_json)
puts "\n\n"
puts employees.to_xml
