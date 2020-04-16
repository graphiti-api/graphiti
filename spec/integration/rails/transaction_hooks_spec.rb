# rubocop: disable Style/GlobalVars

if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "after_graph_persist, before_ & after_commit hooks", type: :controller do
    class Callbacks
      class << self
        attr_accessor :fired, :in_transaction_during, :entities

        def add(name, object)
          fired[name] = object
          in_transaction_during[name] = in_transaction?
          entities << name
        end

        private

        def in_transaction?
          # The test harness wraps everything in a transaction, so we know
          # we are inside a transaction from the library itself if we have 2
          # or more open transactions
          ActiveRecord::Base.connection.open_transactions > 1
        end
      end
    end

    before do
      Callbacks.fired = {}
      Callbacks.in_transaction_during = {}
      Callbacks.entities = []
      $raise_on_after_graph_persist = {employee: false}
      $raise_on_before_commit = {employee: true}
    end

    before do
      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with("PATH_INFO") { path }
    end

    let(:path) { "/integration_hooks/employees" }

    module IntegrationHooks
      class ApplicationResource < Graphiti::Resource
        self.adapter = Graphiti::Adapters::ActiveRecord
      end

      class DepartmentResource < ApplicationResource
        self.model = ::Department

        before_commit do |department|
          Callbacks.add(:before_department, department)
          if $raise_on_before_commit[:department]
            raise "rollitback_department"
          end
        end
      end

      class PositionResource < ApplicationResource
        self.model = ::Position

        attribute :employee_id, :integer, only: [:writable]

        before_commit do |position|
          Callbacks.add(:before_position, position)
          if $raise_on_before_commit[:position]
            raise "rollitback_position"
          end
        end

        belongs_to :department
      end

      class EmployeeResource < ApplicationResource
        self.model = ::Employee

        attribute :first_name, :string

        after_graph_persist do |employee|
          Callbacks.add(:after_graph_persist, employee)
          if $raise_on_after_graph_persist[:employee]
            raise "rollitback"
          end
        end

        before_commit only: [:create] do |employee|
          Callbacks.add(:before_create, employee)
          if $raise_on_before_commit[:employee]
            raise "rollitback"
          end
        end

        # Stacking second callback on create
        before_commit only: [:create] do |employee|
          Callbacks.add(:stacked_before_create, employee)
        end

        before_commit only: [:update] do |employee|
          Callbacks.add(:before_update, employee)
          if $raise_on_before_commit[:employee]
            raise "rollitback"
          end
        end

        before_commit only: [:destroy] do |employee|
          Callbacks.add(:before_destroy, employee)
          if $raise_on_before_commit[:employee]
            raise "rollitback"
          end
        end

        after_commit only: :create do |employee|
          Callbacks.add(:employee_after_create, employee)
        end

        after_commit do |employee|
          Callbacks.add(:employee_after_create_eval_test, self)
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
          raise "whoops"
        end
      end

      def update
        employee = resource.find(params)

        if employee.update_attributes
          render_jsonapi(employee, scope: false)
        else
          raise "whoops"
        end
      end

      def destroy
        employee = resource.find(params)

        if employee.destroy
          render jsonapi: employee
        else
          raise "whoops"
        end
      end

      def resource
        IntegrationHooks::EmployeeResource
      end

      private

      def params
        @params ||= begin
          hash = super.to_unsafe_h.with_indifferent_access
          hash = hash[:params] if hash.key?(:params)
          hash
        end
      end
    end

    before do
      @request.headers["Accept"] = Mime[:json]
      @request.headers["Content-Type"] = Mime[:json].to_s

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
          type: "employees",
          attributes: {first_name: "Jane"}
        }
      }
    end

    context "on create" do
      it "fires before_commit hooks after validations but before ending the transaction" do
        expect_any_instance_of(Graphiti::Util::ValidationResponse)
          .to receive(:validate!)
        expect {
          post :create, params: payload
        }.to raise_error("rollitback")
        expect(Employee.count).to be_zero
        expect(Callbacks.entities.length).to eq(2)
        expect(Callbacks.fired[:before_create]).to be_a(Employee)
      end

      context "when an error is raised before_commit" do
        it "does not run after_commit callbacks" do
          expect {
            post :create, params: payload
          }.to raise_error("rollitback")
          expect(Callbacks.entities).not_to include(:employee_after_create)
        end
      end

      context "when validation fails" do
        let(:validation_response) do
          double("Graphiti::Util::ValidationResponse").as_null_object
        end

        before do
          allow_any_instance_of(Graphiti::Util::ValidationResponse)
            .to receive(:validate!).and_raise(Graphiti::Errors::ValidationError, validation_response)
        end

        it "does not run any callbacks" do
          expect {
            post :create, params: payload
          }.to raise_error("whoops")
          expect(Callbacks.entities).to include(:after_graph_persist)
        end
      end

      context "when stacking" do
        before do
          $raise_on_before_commit = {employee: false}
        end

        it "fires all before and after_commit hooks" do
          post :create, params: payload
          expect(Callbacks.entities).to eq([
            :after_graph_persist,
            :before_create,
            :stacked_before_create,
            :employee_after_create,
            :employee_after_create_eval_test
          ])
        end
      end

      context "when an error is raised after_graph_persist" do
        before do
          $raise_on_after_graph_persist = {employee: true}
        end

        it "does not run before_commit callbacks" do
          expect_any_instance_of(Graphiti::Util::ValidationResponse)
            .to_not receive(:validate!)
          expect {
            post :create, params: payload
          }.to raise_error("rollitback")
          expect(Employee.count).to be_zero
          expect(Callbacks.entities.length).to eq(1)
          expect(Callbacks.fired[:after_graph_persist]).to be_a(Employee)
        end
      end
    end

    context "nested" do
      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "joe"},
            relationships: {
              positions: {
                data: [
                  {'temp-id': "a", type: "positions", method: "create"}
                ]
              }
            }
          },
          included: [
            {
              type: "positions",
              'temp-id': "a",
              relationships: {
                department: {
                  data: {
                    'temp-id': "b", type: "departments", method: "create"
                  }
                }
              }
            },
            {
              type: "departments",
              'temp-id': "b"
            }
          ]
        }
      end

      before do
        $raise_on_before_commit = {}
      end

      it "fires before_commit and after_commit hooks" do
        post :create, params: payload

        expect(Callbacks.entities).to eq([
          :after_graph_persist,
          :before_create,
          :stacked_before_create,
          :before_position,
          :before_department,
          :employee_after_create,
          :employee_after_create_eval_test
        ])
      end

      it "fires before_commit after validations but before ending the transaction" do
        expect_any_instance_of(Graphiti::Util::ValidationResponse)
          .to receive(:validate!)

        post :create, params: payload
        expect(Callbacks.fired[:before_create]).to be_a(Employee)
        expect(Callbacks.in_transaction_during[:before_create]).to eq true
        expect(Callbacks.fired[:before_position]).to be_a(Position)
        expect(Callbacks.in_transaction_during[:before_position]).to eq true
        expect(Callbacks.fired[:before_department]).to be_a(Department)
        expect(Callbacks.in_transaction_during[:before_department]).to eq true
      end

      it "fires after_commit hooks after ending the transaction" do
        post :create, params: payload
        expect(Callbacks.fired[:employee_after_create]).to be_a(Employee)
        expect(Callbacks.in_transaction_during[:employee_after_create]).to eq false
        expect(Callbacks.fired[:employee_after_create_eval_test]).to be_a(IntegrationHooks::EmployeeResource)
      end

      it "can access children resources from after_graph_persist" do
        post :create, params: payload
        expect(Callbacks.fired[:employee_after_create].positions.length).to eq(1)
        expect(Callbacks.fired[:employee_after_create].positions[0]).to be_a(Position)
      end
    end

    context "when yielding meta" do
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
            type: "employees",
            attributes: {first_name: "Jane"},
            relationships: {
              positions: {
                data: {
                  type: "positions", 'temp-id': "abc123", method: "create"
                }
              }
            }
          },
          included: [
            {
              type: "positions",
              'temp-id': "abc123",
              attributes: {title: "foo"}
            }
          ]
        }
      end

      before do
        klass.has_many :positions, resource: position_resource
        allow(controller).to receive(:resource) { klass }
      end

      it "gets correct metadata" do
        post :create, params: payload
        expect(klass.meta).to eq({
          method: :create,
          temp_id: nil,
          caller_model: nil,
          attributes: {"first_name" => "Jane"},
          relationships: {
            positions: {
              meta: {
                jsonapi_type: "positions",
                temp_id: "abc123",
                method: :create,
                payload_path: ["included", 0]
              },
              attributes: {
                "title" => "foo",
                "employee_id" => 1
              },
              relationships: {}
            }
          }
        })
        expect(position_resource.meta.except(:caller_model)).to eq({
          method: :create,
          temp_id: "abc123",
          attributes: {
            "title" => "foo",
            "employee_id" => 1
          },
          relationships: {}
        })

        expect(position_resource.meta[:caller_model]).to be_a(::Employee)
      end
    end
  end
end

# rubocop: enable Style/GlobalVars
