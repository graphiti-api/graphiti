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
            team_memberships: [],
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

      # TODO: the integer casting here should go away with attribute types
      def apply_filtering(records, params)
        return records unless params[:conditions]
        records.select! do |record|
          params[:conditions].all? do |key, value|
            db_value = record.send(key)
            if key == :id
              value = value.is_a?(Array) ? value.map(&:to_i) : value.to_i
            end
            if value.is_a?(Array)
              value.include?(db_value)
            else
              db_value == value
            end
          end
        end
        records
      end

      def apply_sorting(records, params)
        return records if params[:sort].nil?

        params[:sort].reverse.each do |sort|
          records.sort! do |a, b|
            att = sort.keys[0]
            a.send(att) <=> b.send(att)
          end
          records = records.reverse if sort.values[0] == :desc
        end
        records
      end

      def apply_pagination(records, params)
        return records unless params[:per]

        start_at = (params[:page]-1)*(params[:per])
        end_at = (params[:page] * params[:per]) -1
        return [] if end_at < 0
        records[start_at..end_at]
      end
    end
  end

  class Base
    attr_accessor :id

    def self.create(attrs = {})
      id = DB.data[type].length + 1
      attrs = { id: id }.merge(attrs)
      DB.data[type] << attrs
      new(attrs)
    end

    def self.type
      name.underscore.pluralize.split('/').last.to_sym
    end

    def initialize(attrs = {})
      attrs.each_pair { |k,v| send(:"#{k}=", v) }
    end

    def update_attributes(attrs)
      record = DB.data[self.class.type].find { |r| r[:id] == id }
      record.merge!(attrs)
    end
  end

  class Employee < Base
    attr_accessor :first_name,
      :last_name,
      :age,
      :active,
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

  class Adapter < JsonapiCompliable::Adapters::Null
    def order(scope, att, dir)
      scope[:sort] ||= []
      scope[:sort] << { att => dir }
      scope
    end

    def paginate(scope, current_page, per_page)
      scope.merge!(page: current_page, per: per_page)
    end

    def filter(scope, name, value)
      scope[:conditions] ||= {}
      scope[:conditions].merge!(name => value)
      scope
    end

    # No need for actual logic to fire
    def count(scope, attr)
       "poro_count_#{attr}"
    end

    def sum(scope, attr)
      "poro_sum_#{attr}"
    end

    def average(scope, attr)
      "poro_average_#{attr}"
    end

    def maximum(scope, attr)
      "poro_maximum_#{attr}"
    end

    def minimum(scope, attr)
      "poro_minimum_#{attr}"
    end
  end

  class ApplicationResource < JsonapiCompliable::Resource
    self.adapter = Adapter.new

    def resolve(scope)
      ::PORO::DB.all(scope)
    end
  end

  class EmployeeResource < ApplicationResource
    self.type = :employees
    self.model = PORO::Employee

    has_many :positions
  end

  class PositionResource < ApplicationResource
    self.type = :positions
    self.model = PORO::Position
  end

  class DepartmentResource < ApplicationResource
    self.type = :departments
    self.model = PORO::Department
  end

  class BioResource < ApplicationResource
    self.type = :bios
    self.model = PORO::Bio
  end

  class TeamResource < ApplicationResource
    self.type = :teams
    self.model = PORO::Team
  end

  class SerializableEmployee < JSONAPI::Serializable::Resource
    type :employees

    attribute :first_name
    attribute :last_name
    attribute :age

    is_admin = proc { |c| @context && @context.current_user == 'admin' }
    attribute :salary, if: is_admin do
      100_000
    end

    extra_attribute :stack_ranking do
      rand(999)
    end

    extra_attribute :admin_stack_ranking, if: is_admin do
      rand(999)
    end

    extra_attribute :runtime_id do
      @context.runtime_id
    end

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
