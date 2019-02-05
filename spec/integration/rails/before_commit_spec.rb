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

    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with('PATH_INFO') { path }
    end

    let(:path) { '/integration_hooks/employees' }

    module IntegrationHooks
      class ApplicationResource < Graphiti::Resource
        self.adapter = Graphiti::Adapters::ActiveRecord
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

        # Stacking second callback on create
        before_commit only: [:create] do |employee|
          Callbacks.add(:stacked_create, employee)
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
        employee = resource.build(params)

        if employee.save
          render jsonapi: employee
        else
          raise 'whoops'
        end
      end

      def update
        employee = resource.find(params)

        if employee.update_attributes
          render_jsonapi(employee, scope: false)
        else
          raise 'whoops'
        end
      end

      def destroy
        employee = resource.find(params)

        if employee.destroy
          render jsonapi: employee
        else
          raise 'whoops'
        end
      end

      def resource
        IntegrationHooks::EmployeeResource
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

    let(:payload) do
      {
        data: {
          type: 'employees',
          attributes: { first_name: 'Jane' }
        }
      }
    end

    context 'before_commit' do
      context 'on create' do
        it 'fires after validations but before ending the transaction' do
          expect_any_instance_of(Graphiti::Util::ValidationResponse)
            .to receive(:validate!)
          expect {
            post :create, params: payload
          }.to raise_error('rollitback')
          expect(Employee.count).to be_zero
          expect(Callbacks.entities.length).to eq(1)
          expect(Callbacks.fired[:create]).to be_a(Employee)
        end

        context 'when stacking' do
          before do
            $raise_on_before_commit = { employee: false }
          end

          it 'works' do
            post :create, params: payload
            expect(Callbacks.entities).to eq([:create, :stacked_create])
          end
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
          expect_any_instance_of(Graphiti::Util::ValidationResponse)
            .to receive(:validate!)
          post :create, params: payload
          expect(Callbacks.entities)
            .to eq([:create, :stacked_create, :position, :department])
          expect(Callbacks.fired[:create]).to be_a(Employee)
          expect(Callbacks.fired[:position]).to be_a(Position)
          expect(Callbacks.fired[:department]).to be_a(Department)
        end
      end

      context 'when yielding meta' do
        let(:klass) do
          Class.new(IntegrationHooks::ApplicationResource) do
            class << self
              attr_accessor :meta
            end
            self.model = ::Employee
            self.validate_endpoints = false

            attribute :first_name, :string

            before_commit do |employee, meta|
              self.class.meta = meta
            end
          end
        end

        let(:position_resource) do
          Class.new(IntegrationHooks::ApplicationResource) do
            class << self
              attr_accessor :meta
            end
            self.model = ::Position
            attribute :title, :string
            attribute :employee_id, :string
            before_commit do |position, meta|
              self.class.meta = meta
            end
          end
        end

        let(:payload) do
          {
            data: {
              type: 'employees',
              attributes: { first_name: 'Jane' },
              relationships: {
                positions: {
                  data: {
                    type: 'positions', :'temp-id' => 'abc123', method: 'create'
                  }
                }
              }
            },
            included: [
              {
                type: 'positions',
                :'temp-id' => 'abc123',
                attributes: { title: 'foo' }
              }
            ]
          }
        end

        before do
          klass.has_many :positions, resource: position_resource
          allow(controller).to receive(:resource) { klass }
        end

        it 'gets correct metadata' do
          post :create, params: payload
          expect(klass.meta).to eq({
            method: :create,
            temp_id: nil,
            caller_model: nil,
            attributes: { 'first_name' => 'Jane' },
            relationships: {
              positions: {
                meta: {
                  jsonapi_type: 'positions',
                  temp_id: 'abc123',
                  method: :create
                },
                attributes: {
                  'title' => 'foo',
                  'employee_id' => '1'
                },
                relationships: {}
              }
            }
          })
          expect(position_resource.meta.except(:caller_model)).to eq({
            method: :create,
            temp_id: 'abc123',
            attributes: {
              'title' => 'foo',
              'employee_id' => '1'
            },
            relationships: {}
          })

          expect(position_resource.meta[:caller_model]).to be_a(::Employee)
        end
      end
    end
  end
end
