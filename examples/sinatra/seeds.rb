# A file-backed database, rebuilt on every boot. An in-memory one won't work
# here: sqlite scopes :memory: to a single connection, and puma's request
# threads each get their own from the pool.
ActiveRecord::Base.establish_connection adapter: "sqlite3",
  database: File.join(__dir__, "employee_directory.sqlite3")

ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define(version: 1) do
  create_table :employees, force: true do |t|
    t.string :first_name
    t.string :last_name
    t.integer :age
  end

  create_table :positions, force: true do |t|
    t.integer :employee_id
    t.integer :department_id
    t.string :title
  end

  create_table :departments, force: true do |t|
    t.string :name
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Employee < ApplicationRecord
  has_many :positions
end

class Position < ApplicationRecord
  belongs_to :employee
  belongs_to :department
end

class Department < ApplicationRecord
  has_many :positions
end

e = Employee.create!(first_name: "Walter", last_name: "White", age: 50)
d = Department.create!(name: "Product")
Position.create!(title: "Cook", department: d, employee: e)

e = Employee.create!(first_name: "Jesse", last_name: "Pinkman", age: 23)
Position.create!(title: "Junior Cook", department: d, employee: e)

d = Department.create!(name: "Legal")
e = Employee.create!(first_name: "Saul", last_name: "Goodman", age: 47)
Position.create!(title: "Lawyer", department: d, employee: e)
