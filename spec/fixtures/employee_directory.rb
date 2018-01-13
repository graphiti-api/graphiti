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

  create_table :teams do |t|
    t.string :name
  end

  create_table :employee_teams do |t|
    t.integer :team_id
    t.integer :employee_id
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

  create_table :salaries do |t|
    t.integer :employee_id
    t.decimal :base_rate
    t.decimal :overtime_rate
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Classification < ApplicationRecord
  has_many :employees
  validates :description, presence: true
end

class Team < ApplicationRecord
  has_many :employee_teams
  has_many :employees, through: :employee_teams
end

class EmployeeTeam < ApplicationRecord
  belongs_to :team
  belongs_to :employee
end

class Office < ApplicationRecord
  has_many :employees, as: :workspace
end

class HomeOffice < ApplicationRecord
  has_many :employees, as: :workspace
end

class Employee < ApplicationRecord
  attr_accessor :force_validation_error

  belongs_to :workspace, polymorphic: true
  belongs_to :classification
  has_many :positions
  validates :first_name, presence: true
  validates :delete_confirmation,
    presence: true,
    on: :destroy

  has_many :employee_teams
  has_many :teams, through: :employee_teams

  has_one :salary

  before_destroy do
    add_validation_error if force_validation_error

    if Rails::VERSION::MAJOR >= 5
      throw(:abort) if errors.present?
    else
      errors.blank?
    end
  end

  def add_validation_error
    errors.add(:base, 'Forced validation error')
  end
end

class Position < ApplicationRecord
  belongs_to :employee
  belongs_to :department
end

class Department < ApplicationRecord
  has_many :positions
end

class Salary < ApplicationRecord
  belongs_to :employee
end

class ApplicationResource < JsonapiCompliable::Resource
  use_adapter JsonapiCompliable::Adapters::ActiveRecord
end

class ClassificationResource < ApplicationResource
  type :classifications
  model Classification
end

class TeamResource < ApplicationResource
  type :teams
  model Team
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

class SalaryResource < ApplicationResource
  type :salaries
  model Salary
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
  has_and_belongs_to_many :teams,
    resource: TeamResource,
    scope: -> { Team.all },
    foreign_key: { employee_teams: :employee_id }
  has_one :salary,
    resource: SalaryResource,
    scope: -> { Salary.all },
    foreign_key: :employee_id

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

class SerializableTeam < SerializableAbstract
  type 'teams'

  attribute :name
end

class SerializableEmployee < SerializableAbstract
  type 'employees'

  attribute :first_name
  attribute :last_name
  attribute :age

  belongs_to :classification
  has_many :positions
  has_many :teams

  has_one :salary
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

class SerializableSalary < SerializableAbstract
  type 'salaries'

  attribute :base_rate
  attribute :overtime_rate
end
