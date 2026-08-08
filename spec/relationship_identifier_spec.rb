# frozen_string_literal: true

require "spec_helper"

RSpec.describe "relationship identifiers" do
  include_context "resource testing"

  # let(:base_scope) { { type: :positions } }
  let!(:employee) { PORO::Employee.create }
  let!(:employee2) { PORO::Employee.create }
  let!(:position1) do
    PORO::Position.create employee_id: employee.id,
      department_id: department1.id
  end
  let!(:position2) do
    PORO::Position.create employee_id: employee.id,
      department_id: department2.id
  end
  let!(:department1) { PORO::Department.create }
  let!(:department2) { PORO::Department.create }
  let!(:bio1) { PORO::Bio.create(employee_id: employee.id) }
  let!(:bio2) { PORO::Bio.create(employee_id: employee.id) }
  let!(:team1) do
    PORO::Team.create team_memberships: [
      PORO::TeamMembership.new(employee_id: employee.id, team_id: 1)
    ]
  end
  let!(:team2) do
    PORO::Team.create team_memberships: [
      PORO::TeamMembership.new(employee_id: employee.id, team_id: 2)
    ]
  end

  describe "has_many" do
    context "with default" do
      let(:resource) do
        Class.new(PORO::TeamResource) do
          def self.name
            "PORO::TeamResource"
          end

          has_many :employees
        end
      end

      before do
        allow_any_instance_of(PORO::Team).to receive(:employees) { [employee, employee2] }
        render
      end

      it "does not include anything" do
        expect do
          included("employees")
        end.to raise_error(Graphiti::SpecHelpers::Errors::NoSideloads)
      end

      it "specifies meta[:included] = false" do
        jsonapi_data.each do |record|
          expect(record.relationships["employees"]["meta"]["included"]).to eq(false)
        end
      end

      it "does not includes relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employees"]["data"]
          expect(data).to be_nil
        end
      end
    end
    context "with include directive" do
      let(:resource) do
        Class.new(PORO::TeamResource) do
          def self.name
            "PORO::TeamResource"
          end

          has_many :employees do
            scope do |employee_ids|
              {
                type: :employees,
                conditions: {employee_id: employee_ids}
              }
            end
          end
        end
      end

      before do
        params[:include] = "employees"
        allow_any_instance_of(PORO::Team).to receive(:employees) { [employee, employee2] }
        render
      end

      it "includes employees" do
        expect(included("employees").map(&:id)).to eq([1, 2])
      end

      it "includes relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employees"]["data"]
          expect(data).to_not be_nil
          expect(data.pluck(:type).uniq).to match_array(["employees"])
          expect(data.pluck(:id).uniq).to match_array(%w[1 2])
        end
      end
    end

    context "without include directive and resource_ids: true" do
      let(:resource) do
        Class.new(PORO::TeamResource) do
          def self.name
            "PORO::TeamResource"
          end

          has_many :employees, resource_ids: true do
            scope do |employee_ids|
              {
                type: :employees,
                conditions: {employee_id: employee_ids}
              }
            end
          end
        end
      end

      before do
        allow_any_instance_of(PORO::Team).to receive(:employees) { [employee, employee2] }
        render
      end

      it "does not include anything" do
        expect do
          included("employees")
        end.to raise_error(Graphiti::SpecHelpers::Errors::NoSideloads)
      end

      it "includes relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employees"]["data"]
          expect(data).to_not be_nil
          expect(data.pluck(:type).uniq).to match_array(["employees"])
          expect(data.pluck(:id).uniq).to match_array(%w[1 2])
        end
      end
    end
  end

  describe "belongs_to" do
    context "with include directive" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          belongs_to :employee
        end
      end
      before do
        params[:include] = "employee"
        render
      end

      it "works" do
        expect(included("employees").map(&:id)).to eq([1])
      end

      it "has relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employee"]["data"]

          expect(data[:type]).to eq("employees")
          expect(data[:id]).to eq("1")
        end
      end
    end

    context "with defaults" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          belongs_to :employee
        end
      end

      before do
        allow_any_instance_of(PORO::Position).to receive(:employee) { employee }
        render
      end

      it "has relationship ids" do
        jsonapi_data.each do |record|
          data = record.relationships["employee"]["data"]

          expect(data[:type]).to eq("employees")
          expect(data[:id]).to eq("1")
        end
      end
    end

    context "with a custom primary_key" do
      let!(:named_employee) { PORO::Employee.create(first_name: "Steve") }
      let!(:named_position) { PORO::Position.create(employee_id: "Steve") }

      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          belongs_to :employee, primary_key: :first_name
        end
      end

      it "has no relationship identifiers, rather than the foreign key" do
        render

        record = jsonapi_data.find { |node| node.id == named_position.id }
        expect(record.relationships["employee"].keys).to_not include("data")
      end

      it "still renders the related id when the relationship is included" do
        params[:include] = "employee"
        render

        record = jsonapi_data.find { |node| node.id == named_position.id }
        data = record.relationships["employee"]["data"]

        expect(data[:id]).to eq(named_employee.id.to_s)
      end
    end

    context "with resource_ids: false" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          belongs_to :employee, resource_ids: false do
            scope do |employee_ids|
              {
                type: :employees,
                conditions: {id: employee_ids}
              }
            end
          end
        end
      end

      before do
        allow_any_instance_of(PORO::Position).to receive(:employee) { employee }
        render
      end

      it "has no relationship identifiers" do
        jsonapi_data.each do |record|
          data = record.relationships["employee"]
          expect(data.keys).to_not include("data")
        end
      end
    end

    context "with belongs_to_resource_ids_by_default = :always" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          self.belongs_to_resource_ids_by_default = :always

          belongs_to :employee do
            scope do |employee_ids|
              {
                type: :employees,
                conditions: {id: employee_ids}
              }
            end
          end
        end
      end

      before do
        allow_any_instance_of(PORO::Position).to receive(:employee) { employee }
        render
      end

      it "includes relationship identifiers without the per-relationship option" do
        jsonapi_data.each do |record|
          data = record.relationships["employee"]["data"]

          expect(data[:type]).to eq("employees")
          expect(data[:id]).to eq("1")
        end
      end

      context "and the relationship opts out" do
        let(:resource) do
          Class.new(PORO::PositionResource) do
            def self.name
              "PORO::PositionResource"
            end

            self.belongs_to_resource_ids_by_default = :always

            belongs_to :employee, resource_ids: false do
              scope do |employee_ids|
                {
                  type: :employees,
                  conditions: {id: employee_ids}
                }
              end
            end
          end
        end

        it "honors the relationship over the default" do
          jsonapi_data.each do |record|
            expect(record.relationships["employee"].keys).to_not include("data")
          end
        end
      end
    end

    context "when the relationship is unreadable" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          belongs_to :employee, readable: false
        end
      end

      it "renders no resource ids, and no relationship at all" do
        render

        jsonapi_data.each do |record|
          expect(record.relationships).to_not have_key("employee")
        end
      end

      it "does not treat the foreign key as a source for them" do
        expect(resource.sideloads[:employee].render_resource_ids?).to eq(false)
      end
    end

    context "when the relationship is guarded" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          belongs_to :employee, readable: :admin?

          def admin?
            context.current_user == "admin"
          end
        end
      end

      # Schema generation asks every relationship whether it renders resource
      # ids, with no request to evaluate the guard against.
      it "answers without running the guard" do
        expect {
          Graphiti.with_context(nil) do
            expect(resource.sideloads[:employee].render_resource_ids?).to eq(true)
          end
        }.to_not raise_error
      end

      it "still omits the relationship when the guard denies at render time" do
        Graphiti.with_context(OpenStruct.new(current_user: "basic")) do
          render
        end

        jsonapi_data.each do |record|
          expect(record.relationships).to_not have_key("employee")
        end
      end
    end

    context "with belongs_to_resource_ids_by_default = :never" do
      let(:resource) do
        Class.new(PORO::PositionResource) do
          def self.name
            "PORO::PositionResource"
          end

          self.belongs_to_resource_ids_by_default = :never

          belongs_to :employee
        end
      end

      it "renders no resource ids" do
        render

        jsonapi_data.each do |record|
          expect(record.relationships["employee"].keys).to_not include("data")
        end
      end

      it "still renders them when the request includes the relationship" do
        params[:include] = "employee"
        render

        jsonapi_data.each do |record|
          expect(record.relationships["employee"]["data"][:id]).to eq("1")
        end
      end
    end

    context "with belongs_to_resource_ids_by_default = :always" do
      context "and the relationship is unreadable" do
        let(:resource) do
          Class.new(PORO::PositionResource) do
            def self.name
              "PORO::PositionResource"
            end

            self.belongs_to_resource_ids_by_default = :always

            belongs_to :employee, readable: false
          end
        end

        # Advertising linkage the render can never emit would put schema.json
        # permanently at odds with the payload.
        it "does not claim resource ids for a relationship that renders nothing" do
          expect(resource.sideloads[:employee].render_resource_ids?).to eq(false)

          render
          jsonapi_data.each do |record|
            expect(record.relationships).to_not have_key("employee")
          end
        end
      end

      context "and the relationship is a polymorphic_belongs_to" do
        let(:visa_resource) { PORO::VisaResource }

        let(:resource) do
          visa = PORO::VisaResource
          Class.new(PORO::EmployeeResource) do
            def self.name
              "PORO::EmployeeResource"
            end

            self.belongs_to_resource_ids_by_default = :always

            polymorphic_belongs_to :credit_card do
              group_by(:credit_card_type) do
                on(:Visa).belongs_to :visa, resource: visa
              end
            end
          end
        end

        it "is covered, since it is a belongs_to" do
          expect(resource.sideloads[:credit_card].render_resource_ids?).to eq(true)
        end
      end
    end

    context "when belongs_to_resource_ids_by_default is unset" do
      it "is :foreign_key, leaving the decision to the key itself" do
        expect(PORO::PositionResource.belongs_to_resource_ids_by_default).to eq(:foreign_key)
      end
    end

    context "when belongs_to_resource_ids_by_default is nil" do
      it "is rejected rather than treated as unspecified" do
        expect {
          Class.new(PORO::PositionResource) { self.belongs_to_resource_ids_by_default = nil }
        }.to raise_error(Graphiti::Errors::InvalidBelongsToResourceIds)
      end
    end

    context "when belongs_to_resource_ids_by_default is given something else" do
      it "rejects a boolean rather than guessing which state it meant" do
        expect {
          Class.new(PORO::PositionResource) { self.belongs_to_resource_ids_by_default = true }
        }.to raise_error(
          Graphiti::Errors::InvalidBelongsToResourceIds,
          /must be one of :foreign_key, :always, or :never/
        )
      end
    end
  end

  describe "the 2.x names" do
    def silenced
      Graphiti::DEPRECATOR.silence { yield }
    end

    it "translates the relationship option, which meant the same thing" do
      resource = silenced do
        Class.new(PORO::TeamResource) do
          has_many :employees, always_include_resource_ids: true
        end
      end

      expect(resource.sideloads[:employees].render_resource_ids?).to eq(true)
    end

    it "warns when the relationship option is used" do
      expect(Graphiti::DEPRECATOR).to receive(:deprecation_warning)
        .with(:always_include_resource_ids, /Use :resource_ids instead/)

      Class.new(PORO::TeamResource) do
        has_many :employees, always_include_resource_ids: true
      end
    end

    it "lets the new option win when both are passed" do
      resource = silenced do
        Class.new(PORO::TeamResource) do
          has_many :employees, always_include_resource_ids: true, resource_ids: false
        end
      end

      expect(resource.sideloads[:employees].render_resource_ids?).to eq(false)
    end
  end

  describe "a relationship the model has no method for" do
    let(:resource) do
      Class.new(PORO::TeamResource) do
        def self.name
          "PORO::TeamResource"
        end

        has_many :employees, resource_ids: true
      end
    end

    it "names the resource and the relationship" do
      expect { render }.to raise_error(
        Graphiti::Errors::MissingRelationshipMethod,
        /PORO::TeamResource: relationship :employees is declared, but PORO::Team has no #employees method/
      )
    end

    it "explains that resource_ids is what makes every render read the association" do
      expect { render }.to raise_error(
        Graphiti::Errors::MissingRelationshipMethod,
        /resource_ids is set on this relationship, so every render reads the association/
      )
    end

    context "when the association exists but raises NoMethodError itself" do
      before do
        allow_any_instance_of(PORO::Team).to receive(:employees) do
          nil.some_undefined_method
        end
      end

      it "lets the original error through" do
        expect { render }.to raise_error(NoMethodError, /some_undefined_method/)
      end
    end

    # #receiver raises rather than returning nil for one of these, so the
    # guard cannot reach for it before knowing the error came from a call.
    context "when the association raises a hand-built NoMethodError naming itself" do
      before do
        allow_any_instance_of(PORO::Team).to receive(:employees) do
          raise NoMethodError.new("custom boom", :employees)
        end
      end

      it "lets the original error through" do
        expect { render }.to raise_error(NoMethodError, /custom boom/)
      end
    end

    context "when the association method exists but is private" do
      let(:resource) do
        Class.new(PORO::TeamResource) do
          def self.name
            "PORO::TeamResource"
          end

          has_many :employees, resource_ids: true
        end
      end

      before do
        PORO::Team.class_eval do
          private def employees
            []
          end
        end
      end

      after do
        PORO::Team.send(:remove_method, :employees)
      end

      it "does not claim the method is missing" do
        expect { render }.to raise_error(NoMethodError, /private method/)
      end
    end
  end
end
