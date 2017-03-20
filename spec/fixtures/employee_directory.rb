ActiveRecord::Schema.define(:version => 1) do
  create_table :employees do |t|
    t.string :first_name
    t.string :last_name
    t.integer :age
  end

  create_table :positions do |t|
    t.belongs_to :department, index: true
    t.belongs_to :employee, index: true
    t.string :title
  end

  create_table :departments do |t|
    t.string :name
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Employee < ApplicationRecord
  has_many :positions
  validates :first_name, presence: true
end

class Position < ApplicationRecord
  belongs_to :employee
  belongs_to :department
end

class Department < ApplicationRecord
  has_many :positions
end

class ApplicationResource < JsonapiCompliable::Resource
  use_adapter JsonapiCompliable::Adapters::ActiveRecord
end

class DepartmentResource < ApplicationResource
  type 'departments'
  model Department
end

class PositionResource < ApplicationResource
  type 'positions'
  model Position

  belongs_to :department,
    scope: -> { Department.all },
    foreign_key: :department_id,
    resource: DepartmentResource
end

class EmployeeResource < ApplicationResource
  type 'employees'
  model Employee

  has_many :positions,
    scope: -> { Position.all },
    foreign_key: :employee_id,
    resource: PositionResource
end

class SerializableAbstract < JSONAPI::Serializable::Resource
end

class SerializableEmployee < SerializableAbstract
  type 'employees'

  attribute :first_name
  attribute :last_name
  attribute :age

  has_many :positions
end

class SerializablePosition < SerializableAbstract
  type 'positions'

  attribute :title

  belongs_to :employee
  belongs_to :department
end

class SerializableDepartment < SerializableAbstract
  type 'departments'

  attribute :name

  has_many :positions
end
