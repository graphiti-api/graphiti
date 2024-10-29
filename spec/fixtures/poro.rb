module PORO
  class DB
    class << self
      def data
        @data ||=
          {
            employees: [],
            positions: [],
            departments: [],
            classifications: [],
            bios: [],
            team_memberships: [],
            teams: [],
            paypals: [],
            visas: [],
            gold_visas: [],
            mastercards: [],
            visa_rewards: [],
            mastercard_commercials: [],
            books: [],
            states: [],
            actors: []
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
          classifications: PORO::Classification,
          bios: PORO::Bio,
          teams: PORO::Team,
          paypals: PORO::Paypal,
          visas: PORO::Visa,
          gold_visas: PORO::GoldVisa,
          mastercards: PORO::Mastercard,
          mastercard_commercials: PORO::MastercardCommercial,
          visa_rewards: PORO::VisaReward,
          books: PORO::Book,
          states: PORO::State,
          actors: PORO::Actor
        }
      end

      def all(params)
        target_types = params[:type]
        records = data.select { |k, v| Array(target_types).include?(k) }
        return [] unless records
        records = records.map { |type, records_for_type|
          records_for_type.map { |attrs| klasses[type].new(attrs) }
        }.flatten
        records = apply_filtering(records, params)
        records = apply_sorting(records, params)
        apply_pagination(records, params)
      end

      private

      # TODO: the integer casting here should go away with attribute types
      def apply_filtering(records, params)
        return records unless params[:conditions]
        records.select! do |record|
          params[:conditions].all? do |key, value|
            db_value = record.send(key) if record.respond_to?(key)
            if key == :id
              value = value.is_a?(Array) ? value.map(&:to_i) : value.to_i
            end
            if value.is_a?(Array)
              value.include?(db_value)
            elsif value.is_a?(Hash) && value[:not]
              db_value != value[:not]
            else
              db_value == value
            end
          end
        end
        records
      end

      def apply_sorting(records, params)
        return records if params[:sort].nil?

        params[:sort].reverse_each do |sort|
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
        records = records[params[:offset]..records.length] if params[:offset]

        start_at = (params[:page] - 1) * (params[:per])
        end_at = (params[:page] * params[:per]) - 1
        return [] if end_at < 0
        records[start_at..end_at]
      end
    end
  end

  class Base
    include ActiveModel::Validations
    attr_accessor :id

    def self.create(attrs = {})
      record = new(attrs)

      if record.valid?
        id = attrs[:id] || DB.data[type].length + 1
        attrs[:id] = id
        record.id = id
        DB.data[type] << attrs
      end

      record
    end

    def self.find(id)
      raw = DB.data[type].find { |r| r[:id] == id }
      new(raw) if raw
    end

    def self.type
      name.underscore.pluralize.split("/").last.to_sym
    end

    def initialize(attrs = {})
      attrs.each_pair { |k, v| send(:"#{k}=", v) }
    end

    def update_attributes(attrs)
      attrs.each_pair { |k, v| send(:"#{k}=", v) }

      if valid?
        record = DB.data[self.class.type].find { |r| r[:id] == id }
        record.merge!(attrs)
        true
      else
        false
      end
    end

    def destroy
      DB.data[self.class.type]
        .delete_if { |r| r[:id] == id }
    end

    def attributes
      {}.tap do |attrs|
        instance_variables.each do |iv|
          key = iv.to_s.delete("@").to_sym
          next if key.to_s.starts_with?("__")
          value = instance_variable_get(iv)
          attrs[key] = value
        end
      end
    end

    def save
      record = DB.data[self.class.type].find { |r| r[:id] == id }
      if record
        update_attributes(attributes)
      else
        record = self.class.create(attributes)
        self.id = record.id
        valid?
      end
    end
  end

  class Employee < Base
    attr_accessor :first_name,
      :last_name,
      :age,
      :active,
      :positions,
      :important_positions,
      :current_position,
      :bio,
      :teams,
      :classification,
      :classification_id,
      :credit_card,
      :credit_card_id,
      :cc_id,
      :credit_card_type,
      :payment_processor,
      :salary,
      :credit_cards,
      :things

    def initialize(*)
      super
      @positions ||= []
      @teams ||= []
    end
  end

  class Position < Base
    attr_accessor :title,
      :rank,
      :employee_id,
      :e_id,
      :employee,
      :department_id,
      :department,
      :important_department
  end

  class Classification < Base
    attr_accessor :description
  end

  class Department < Base
    attr_accessor :name, :description, :positions
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

  class CreditCard < Base
    attr_accessor :number, :description, :employee_id
  end

  class Visa < CreditCard
    attr_accessor :visa_only_attr
    attr_accessor :visa_rewards

    def initialize(*)
      super
      @visa_only_attr ||= nil
      @visa_rewards ||= []
    end
  end

  class GoldVisa < Visa
  end

  class Mastercard < CreditCard
    attr_accessor :commercials
  end

  class MastercardCommercial < Base
    attr_accessor :mastercard_id, :runtime, :name, :actors
  end

  class Actor < Base
    attr_accessor :commercial_id, :first_name, :last_name
  end

  class VisaReward < Base
    attr_accessor :visa_id, :points
  end

  class Paypal < Base
    attr_accessor :account_id
  end

  class Book < Base
    attr_accessor :title, :author_id
  end

  class State < Base
    attr_accessor :name
  end

  class Adapter < Graphiti::Adapters::Null
    def order(scope, att, dir)
      scope[:sort] ||= []
      scope[:sort] << {att => dir}
      scope
    end

    def base_scope(model)
      {}
    end

    def paginate(scope, current_page, per_page, offset)
      scope[:page] = current_page if current_page
      scope[:per] = per_page if per_page
      scope[:offset] = offset if offset
      scope
    end

    def filter(scope, name, value)
      scope[:conditions] ||= {}
      scope[:conditions][name] = value
      scope
    end

    def filter_not_eq(scope, name, value)
      scope[:conditions] ||= {}
      scope[:conditions][name] = {not: value}
      scope
    end

    alias_method :filter_integer_eq, :filter
    alias_method :filter_string_eq, :filter
    alias_method :filter_big_decimal_eq, :filter
    alias_method :filter_float_eq, :filter
    alias_method :filter_date_eq, :filter
    alias_method :filter_datetime_eq, :filter
    alias_method :filter_boolean_eq, :filter
    alias_method :filter_hash_eq, :filter
    alias_method :filter_array_eq, :filter
    alias_method :filter_enum_eq, :filter
    alias_method :filter_enum_not_eq, :filter_not_eq
    alias_method :filter_enum_eql, :filter
    alias_method :filter_enum_not_eql, :filter_not_eq

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

    def create(model, attributes)
      model.create(attributes)
    end

    def resolve(scope)
      ::PORO::DB.all(scope)
    end

    def save(model_instance)
      model_instance.save
      model_instance
    end

    def destroy(model_instance)
      model_instance.destroy
      model_instance
    end
  end

  class EmployeeSerializer < Graphiti::Serializer
    extra_attribute :stack_ranking do
      rand(999)
    end

    is_admin = proc { |c| @context && @context.current_user == "admin" }
    extra_attribute :admin_stack_ranking, if: is_admin do
      rand(999)
    end

    extra_attribute :runtime_id do
      @context.runtime_id
    end
  end

  class ApplicationResource < Graphiti::Resource
    self.adapter = Adapter
    self.abstract_class = true

    def base_scope
      {type: model.name.demodulize.underscore.pluralize.to_sym}
    end
  end

  class TeamResource < ApplicationResource
  end

  class EmployeeResource < ApplicationResource
    self.serializer = PORO::EmployeeSerializer
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :age, :integer
    extra_attribute :worth, :integer do
      100
    end
    attribute :salary, :integer, readable: :admin? do
      100_000
    end
    has_many :positions
    many_to_many :teams, foreign_key: {employee_teams: :employee_id}
    has_many :credit_cards # can also belong_to
    has_many :visas
    has_many :gold_visas

    def admin?
      context && context.current_user == "admin"
    end
  end

  class PositionResource < ApplicationResource
    attribute :employee_id, :integer, only: [:filterable]
    attribute :department_id, :integer, only: [:filterable]
    attribute :title, :string
    attribute :rank, :integer
    extra_attribute :score, :integer do
      200
    end
    belongs_to :department
  end

  class ClassificationResource < ApplicationResource
  end

  class DepartmentResource < ApplicationResource
    attribute :name, :string
    attribute :description, :string

    has_many :positions
  end

  class BioResource < ApplicationResource
  end

  class CreditCardResource < ApplicationResource
    self.polymorphic = %w[PORO::VisaResource PORO::GoldVisaResource PORO::MastercardResource]

    def base_scope
      {type: [:visas, :gold_visas, :mastercards]}
    end

    attribute :number, :integer
    attribute :description, :string
    filter :employee_id, :integer

    extra_attribute :credit_score, :integer do
      999
    end
  end

  class VisaResource < CreditCardResource
    attribute :description, :string do
      "visa description"
    end
    attribute :visa_only_attr, :string do
      "visa only"
    end

    def base_scope
      {type: :visas}
    end

    has_many :visa_rewards
  end

  class GoldVisaResource < VisaResource
  end

  class ActorResource < ApplicationResource
    filter :commercial_id, :integer
    attribute :first_name, :string
    attribute :last_name, :string

    def base_scope
      {type: :actors}
    end
  end

  class MastercardCommercialResource < ApplicationResource
    filter :mastercard_id, :integer
    attribute :runtime, :integer
    attribute :name, :string

    def base_scope
      {type: :mastercard_commercials}
    end

    has_many :actors, foreign_key: :commercial_id
  end

  class MastercardResource < CreditCardResource
    attribute :description, :string do
      "mastercard description"
    end

    def base_scope
      {type: :mastercards}
    end

    has_many :commercials, resource: PORO::MastercardCommercialResource
  end

  class VisaRewardResource < ApplicationResource
    attribute :visa_id, :integer, only: [:filterable]
    attribute :points, :integer

    def base_scope
      {type: :visa_rewards}
    end
  end

  class PaypalResource < ApplicationResource
    attribute :account_id, :integer

    def base_scope
      {type: :paypals}
    end
  end

  class ApplicationSerializer < Graphiti::Serializer
  end
end
