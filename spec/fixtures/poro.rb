module PORO
  class DB
    class << self
      def data
        @data ||=
          {
            employees: [],
            positions: [],
            departments: [],
            bios: [],
            teams: []
          }
      end

      def clear
        data.each_pair do |key, value|
          data[key] = []
        end
      end

      def klasses
        {
          employees: PORO::Employee,
          positions: PORO::Position,
          departments: PORO::Department,
          bios: PORO::Bio,
          teams: PORO::Team
        }
      end

      def all(params)
        type = params[:type]
        records = data[type].map { |attrs| klasses[type].new(attrs) }
        records = apply_filtering(records, params)
        records = apply_sorting(records, params)
        records = apply_pagination(records, params)
        records
      end

      private

      def apply_filtering(records, params)
        return records unless params[:conditions]
        records.select! do |record|
          params[:conditions].all? do |key, value|
            if value.is_a?(Array)
              value.include?(record.send(key))
            else
              record.send(key) == value
            end
          end
        end
        records
      end

      def apply_sorting(records, params)
        return records unless params[:sort]
        records.sort! do |a, b|
          att = params[:sort].keys[0]
          a.send(att) <=> b.send(att)
        end
        records = records.reverse if params[:sort].values[0] == :desc
        records
      end

      def apply_pagination(records, params)
        return records unless params[:per]
        records.take(params[:per])
      end
    end
  end

  class Base
    attr_accessor :id

    def initialize(attrs = {})
      attrs.each_pair { |k,v| send(:"#{k}=", v) }
    end
  end

  class Employee < Base
    attr_accessor :first_name,
      :last_name,
      :positions,
      :bio,
      :teams

    def initialize(*)
      super
      @positions ||= []
      @teams ||= []
    end
  end

  class Position < Base
    attr_accessor :title,
      :employee_id,
      :e_id,
      :employee,
      :department_id,
      :department
  end

  class Department < Base
    attr_accessor :name
  end

  class Bio < Base
    attr_accessor :text, :employee_id, :employee
  end

  class TeamMembership < Base
    attr_accessor :employee_id, :team_id
  end

  class Team < Base
    attr_accessor :name, :team_memberships
  end

  class ApplicationResource < JsonapiCompliable::Resource
    use_adapter JsonapiCompliable::Adapters::Null

    sort do |scope, att, dir|
      scope.merge!(sort: { att => dir })
    end

    paginate do |scope, current_page, per_page|
      scope.merge!(page: current_page, per: per_page)
    end

    def resolve(scope)
      ::PORO::DB.all(scope)
    end
  end

  class EmployeeResource < ApplicationResource
    type :employees
    model PORO::Employee

    has_many :positions
  end

  class PositionResource < ApplicationResource
    type :positions
    model PORO::Position
  end

  class DepartmentResource < ApplicationResource
    type :departments
    model PORO::Department
  end

  class BioResource < ApplicationResource
    type :bios
    model PORO::Bio
  end

  class TeamResource < ApplicationResource
    type :teams
    model PORO::Team
  end

  class SerializableEmployee < JSONAPI::Serializable::Resource
    type :employees

    attribute :first_name
    attribute :last_name

    has_many :positions
    has_many :teams
    has_one :bio
  end

  class SerializablePosition < JSONAPI::Serializable::Resource
    type :positions

    attribute :title

    belongs_to :employee
    belongs_to :department
  end

  class SerializableDepartment < JSONAPI::Serializable::Resource
    type :departments

    attribute :name
  end

  class SerializableBio < JSONAPI::Serializable::Resource
    type :bios

    attribute :text
  end

  class SerializableTeam < JSONAPI::Serializable::Resource
    type :teams

    attribute :name
  end
end
