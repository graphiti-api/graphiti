if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe 'before_commit hook', type: :controller do
    class Callbacks
      class << self
        attr_accessor :fired, :entities
      end

      def self.add(name, object)
        self.fired[name] = object
        self.entities << name
      end
    end

    before do
      Callbacks.fired = {}
      Callbacks.entities = []
      $raise_on_before_commit = { employee: true }
    end

    module IntegrationHooks
      class ApplicationResource < JsonapiCompliable::Resource
        self.adapter = JsonapiCompliable::Adapters::ActiveRecord::Base.new
      end

      class DepartmentResource < ApplicationResource
        self.model = ::Department

        before_commit do |department|
          Callbacks.add(:department, department)
          if $raise_on_before_commit[:department]
            raise 'rollitback_department'
          end
        end
      end

      class PositionResource < ApplicationResource
        self.model = ::Position

        attribute :employee_id, :integer, only: [:writable]

        before_commit do |position|
          Callbacks.add(:position, position)
          if $raise_on_before_commit[:position]
            raise 'rollitback_book'
          end
        end

        belongs_to :department
      end

      class EmployeeResource < ApplicationResource
        self.model = ::Employee

        attribute :first_name, :string

        before_commit only: [:create] do |employee|
          Callbacks.add(:create, employee)
          if $raise_on_before_commit[:employee]
            raise 'rollitback'
          end
        end

        before_commit only: [:update] do |employee|
          Callbacks.add(:update, employee)
          if $raise_on_before_commit[:employee]
            raise 'rollitback'
          end
        end

        before_commit only: [:destroy] do |employee|
          Callbacks.add(:destroy, employee)
          if $raise_on_before_commit[:employee]
            raise 'rollitback'
          end
        end

        has_many :positions
      end
    end

    controller(ApplicationController) do
      def create
        employee = IntegrationHooks::EmployeeResource.build(params)

        if employee.save
          render jsonapi: employee
        else
          raise 'whoops'
        end
      end

      def update
        employee = IntegrationHooks::EmployeeResource.find(params)

        if employee.update_attributes
          render_jsonapi(employee, scope: false)
        else
          raise 'whoops'
        end
      end

      def destroy
        employee = IntegrationHooks::EmployeeResource.find(params)

        if employee.destroy
          render jsonapi: employee
        else
          raise 'whoops'
        end
      end

      private

      def params
        @params ||= begin
          hash = super.to_unsafe_h.with_indifferent_access
          hash = hash[:params] if hash.has_key?(:params)
          hash
        end
      end
    end

    before do
      @request.headers['Accept'] = Mime[:json]
      @request.headers['Content-Type'] = Mime[:json].to_s

      routes.draw {
        post "create" => "anonymous#create"
        put "update" => "anonymous#update"
        delete "destroy" => "anonymous#destroy"
      }
    end

    def json
      JSON.parse(response.body)
    end

    context 'before_commit' do
      context 'on create' do
        let(:payload) do
          {
            data: {
              type: 'employees',
              attributes: { first_name: 'Jane' }
            }
          }
        end

        it 'fires after validations but before ending the transaction' do
          expect_any_instance_of(JsonapiCompliable::Util::ValidationResponse)
            .to receive(:validate!)
          expect {
            post :create, params: payload
          }.to raise_error('rollitback')
          expect(Employee.count).to be_zero
          expect(Callbacks.entities.length).to eq(1)
          expect(Callbacks.fired[:create]).to be_a(Employee)
        end
      end

      context 'nested' do
        let(:payload) do
          {
            data: {
              type: 'employees',
              attributes: { first_name: 'joe' },
              relationships: {
                positions: {
                  data: [
                    { :'temp-id' => 'a', type: 'positions', method: 'create' }
                  ]
                }
              }
            },
            included: [
              {
                type: 'positions',
                :'temp-id' => 'a',
                relationships: {
                  department: {
                    data: {
                      :'temp-id' => 'b', type: 'departments', method: 'create'
                    }
                  }
                }
              },
              {
                type: 'departments',
                :'temp-id' => 'b'
              }
            ]
          }
        end

        before do
          $raise_on_before_commit = {}
        end

        it 'fires after validations but before ending the transaction' do
          expect_any_instance_of(JsonapiCompliable::Util::ValidationResponse)
            .to receive(:validate!)
          post :create, params: payload
          expect(Callbacks.entities)
            .to eq([:create, :position, :department])
          expect(Callbacks.fired[:create]).to be_a(Employee)
          expect(Callbacks.fired[:position]).to be_a(Position)
          expect(Callbacks.fired[:department]).to be_a(Department)
        end
      end
    end
  end
end
