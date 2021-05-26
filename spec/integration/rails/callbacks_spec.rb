# rubocop: disable Style/GlobalVars

if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe "persistence callbacks", type: :controller do
    before do
      @request.headers["Accept"] = Mime[:json]
      @request.headers["Content-Type"] = Mime[:json].to_s

      routes.draw do
        post "create" => "anonymous#create"
        put "update" => "anonymous#update"
        delete "destroy" => "anonymous#destroy"
      end

      allow(controller.request.env).to receive(:[])
        .with(anything).and_call_original
      allow(controller.request.env).to receive(:[])
        .with("PATH_INFO") { path }
    end

    after do
      Thread.current[:proxy] = nil
    end

    def proxy
      Thread.current[:proxy]
    end

    let(:path) { "/integration_callbacks/employees" }

    module IntegrationCallbacks
      class ApplicationResource < Graphiti::Resource
        self.adapter = Graphiti::Adapters::ActiveRecord
      end

      class EmployeeResource < ApplicationResource
        self.model = Employee
        self.type = "employees"

        before_attributes :one
        before_attributes :two

        after_attributes :three
        after_attributes :four

        around_attributes :five
        around_attributes :six
        around_attributes :seven

        before_save :eight
        before_save :nine

        after_save :ten
        after_save :eleven

        around_save :twelve
        around_save :thirteen
        around_save :fourteen

        before_destroy :destroy1
        after_destroy :destroy2
        around_destroy :destroy3
        around_destroy :destroy4

        attribute :first_name, :string

        def one(attributes)
          attributes[:first_name] << "1"
        end

        def two(attributes)
          attributes[:first_name] << "2"
        end

        def three(model)
          model.first_name << "3"
        end

        def four(model)
          model.first_name << "4"
        end

        def five(attributes)
          fname = attributes[:first_name].dup
          fname << "5a"
          model = yield(first_name: fname)
          model.first_name << "5b"
        end

        def six(attributes)
          fname = attributes[:first_name].dup
          fname << "6a"
          model = yield(first_name: fname)
          model.first_name << "6b"
        end

        def seven(attributes)
          fname = attributes[:first_name].dup
          fname << "7a"
          model = yield(first_name: fname)
          model.first_name << "7b"
        end

        def eight(model)
          model.first_name << "8"
        end

        def nine(model)
          model.first_name << "9"
        end

        def ten(model)
          model.first_name << "_10"
        end

        def eleven(model)
          model.first_name << "_11"
        end

        def twelve(model)
          model.first_name << "_12a"
          yield model
          model.first_name << "_12b"
        end

        def thirteen(model)
          model.first_name << "_13a"
          raise("test") if $raise
          yield model
          model.first_name << "_13b"
        end

        def fourteen(model)
          model.first_name << "_14a"
          yield model
          model.first_name << "_14b"
        end

        def destroy1(model)
          model.first_name << "d1"
        end

        def destroy2(model)
          model.first_name << "d2"
        end

        def destroy3(model)
          model.first_name << "_d3a"
          yield model
          model.first_name << "_d3b"
        end

        def destroy4(model)
          model.first_name << "_d4a_"
          yield model
          model.first_name << "_d4b"
        end
      end
    end

    controller(ApplicationController) do
      def create
        employee = IntegrationCallbacks::EmployeeResource.build(params)
        Thread.current[:proxy] = employee

        if employee.save
          render jsonapi: employee
        else
          raise "whoops"
        end
      end

      def update
        employee = IntegrationCallbacks::EmployeeResource._find(params)
        Thread.current[:proxy] = employee
        employee.assign_attributes

        if employee.update_attributes
          render jsonapi: employee
        else
          raise "whoops"
        end
      end

      def destroy
        employee = IntegrationCallbacks::EmployeeResource._find(params)
        Thread.current[:proxy] = employee

        if employee.destroy
          render jsonapi: employee
        else
          raise "whoops"
        end
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

    let(:payload) do
      {
        data: {
          type: "employees",
          attributes: {first_name: "Jane"}
        }
      }
    end

    after do
      $raise = false
    end

    describe "lifecycle" do
      describe "save callbacks" do
        it "fires hooks in order" do
          expect {
            post :create, params: payload
          }.to change { Employee.count }.by(1)
          employee = proxy.data
          expect(employee.first_name)
            .to eq("Jane5a6a7a12347b6b5b_12a_13a_14a89_10_11_14b_13b_12b")
        end

        context "when an error is raised" do
          before do
            $raise = true
          end

          it "rolls back the transaction" do
            expect {
              expect { post :create, params: payload }.to raise_error("test")
            }.to_not(change { Employee.count })
          end
        end
      end

      describe "update callbacks" do
        let!(:employee) { Employee.create!(first_name: "asdf") }
        let(:payload) {
          {id: employee.id,
           data: {
             id: employee.id,
             type: "employees",
             attributes: {first_name: "Jane"}
           }}
        }

        it "fires hooks in order" do
          expect {
            put :update, params: payload
          }.to change { Employee.find(employee.id).first_name }
          employee = proxy.data
          expect(employee.first_name)
            .to eq("Jane5a6a7a12347b6b5b_12a_13a_14a89_10_11_14b_13b_12b")
        end

        context "when an error is raised" do
          before do
            $raise = true
          end

          it "rolls back the transaction" do
            expect {
              expect { put :update, params: payload }.to raise_error("test")
            }.to_not(change { Employee.count })
          end
        end
      end

      describe "destroy callbacks" do
        let!(:employee) { Employee.create!(first_name: "Jane") }

        it "fires correctly" do
          if Rails::VERSION::MAJOR >= 5
            delete :destroy, params: {id: employee.id}
          else
            delete :destroy, id: employee.id
          end

          employee = proxy.data
          expect(employee.first_name).to eq("Jane_d3a_d4a_d1d2_d4b_d3b")
        end
      end
    end
  end
end

# rubocop: enable Style/GlobalVars
