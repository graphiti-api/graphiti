ActiveRecord::Schema.define(:version => 1) do
  create_table :classifications do |t|
    t.string :description
  end

  create_table :offices do |t|
    t.string :address
  end

  create_table :home_offices do |t|
    t.string :address
  end

  create_table :employees do |t|
    t.string :workspace_type
    t.integer :workspace_id
    t.integer :classification_id
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

class Classification < ApplicationRecord
  has_many :employees
  validates :description, presence: true
end

class Office < ApplicationRecord
  has_many :employees, as: :workspace
end

class HomeOffice < ApplicationRecord
  has_many :employees, as: :workspace
end

class Employee < ApplicationRecord
  belongs_to :workspace, polymorphic: true
  belongs_to :classification
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

class ClassificationResource < ApplicationResource
  type :classifications
  model Classification
end

class DepartmentResource < ApplicationResource
  type :departments
  model Department
end

class PositionResource < ApplicationResource
  type :positions
  model Position

  belongs_to :department,
    scope: -> { Department.all },
    foreign_key: :department_id,
    resource: DepartmentResource
end

class OfficeResource < ApplicationResource
  type :offices
  model Office
end

class HomeOfficeResource < ApplicationResource
  type :home_offices
  model HomeOffice
end

class EmployeeResource < ApplicationResource
  type :employees
  model Employee

  belongs_to :classification,
    scope: -> { Classification.all },
    foreign_key: :classification_id,
    resource: ClassificationResource
  has_many :positions,
    scope: -> { Position.all },
    foreign_key: :employee_id,
    resource: PositionResource
  polymorphic_belongs_to :workspace,
    group_by: :workspace_type,
    groups: {
      'Office' => {
        scope: -> { Office.all },
        resource: OfficeResource,
        foreign_key: :workspace_id
      },
      'HomeOffice' => {
        scope: -> { HomeOffice.all },
        resource: HomeOfficeResource,
        foreign_key: :workspace_id
      }
    }
end

class SerializableAbstract < JSONAPI::Serializable::Resource
end

class SerializableClassification < SerializableAbstract
  type 'classifications'

  attribute :description
end

class SerializableEmployee < SerializableAbstract
  type 'employees'

  attribute :first_name
  attribute :last_name
  attribute :age

  belongs_to :classification
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
