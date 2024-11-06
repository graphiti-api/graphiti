require "spec_helper"

RSpec.describe "sideloading" do
  include_context "resource testing"
  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end
  let(:base_scope) { {type: :employees} }

  module Sideloading
    class CustomPositionResource < ::PORO::PositionResource
      self.default_sort = [{id: :desc}]
    end

    class PositionSideload < ::Graphiti::Sideload::HasMany
      scope do |employee_ids|
        {type: :positions, sort: [{id: :desc}]}
      end
    end
  end

  let!(:employee) { PORO::Employee.create }
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

  context "when basic manual sideloading" do
    before do
      resource.class_eval do
        allow_sideload :positions, type: :has_many do
          scope do |employee_ids|
            {
              type: :positions,
              conditions: {employee_id: employee_ids}
            }
          end

          assign_each do |employee, positions|
            positions.select { |p| p.employee_id == employee.id }
          end
        end
      end
    end

    it "works" do
      params[:include] = "positions"
      render
      expect(included("positions").map(&:id)).to eq([1, 2])
    end

    context "and deep querying" do
      before do
        params[:include] = "positions"
        params[:sort] = "-positions.id"
      end

      it "works" do
        render
        expect(included("positions").map(&:id)).to eq([2, 1])
      end
    end

    context "and scope block with second argument" do
      before do
        resource.class_eval do
          allow_sideload :positions, type: :has_many do
            scope do |employee_ids, employees|
              {type: :positions, employee_ids: employees.map(&:id)}
            end

            assign_each do |employee, positions|
              positions.select { |p| p.employee_id == employee.id }
            end
          end
        end
        params[:include] = "positions"
      end

      let!(:employee2) { PORO::Employee.create }
      let!(:employees) { [employee, employee2] }

      it "correctly passes parents" do
        expect(PORO::DB).to receive(:all).and_call_original
        expect(PORO::DB).to receive(:all)
          .with(hash_including(employee_ids: employees.map(&:id))) { [] }
        render
      end
    end
  end

  context "when singular association" do
    before do
      resource.class_eval do
        allow_sideload :positions, type: :has_many, single: true do
          scope do |employee_ids, employees|
            {type: :positions, employee_ids: employees.map(&:id)}
          end

          assign_each do |employee, positions|
            positions.select { |p| p.employee_id == employee.id }
          end
        end
      end
      params[:include] = "positions"
    end

    context "and multiple parents" do
      let!(:employee2) { PORO::Employee.create }
      let!(:employees) { [employee, employee2] }

      it "raises error" do
        expect {
          render
        }.to raise_error(Graphiti::Errors::SingularSideload, /:positions with single: true/)
      end
    end

    context "and single parent" do
      it "works" do
        expect {
          render
        }.to_not raise_error
      end
    end
  end

  context "when using .assign instead of .assign_each" do
    before do
      resource.class_eval do
        allow_sideload :positions, type: :has_many do
          scope do |employee_ids|
            {
              type: :positions,
              conditions: {employee_id: employee_ids}
            }
          end

          assign do |employees, positions|
            employees.each do |e|
              relevant = positions.select { |p| p.employee_id == e.id }
              e.positions = relevant
            end
          end
        end
      end
      params[:include] = "positions"
    end

    it "works" do
      render
      expect(included("positions").map(&:id)).to eq([1, 2])
    end
  end

  context "when custom resource option given" do
    before do
      resource.class_eval do
        allow_sideload :positions, type: :has_many, resource: Sideloading::CustomPositionResource do
          scope do |employee_ids|
            {
              type: :positions,
              conditions: {employee_id: employee_ids}
            }
          end

          assign_each do |employee, positions|
            positions.select { |p| p.employee_id == employee.id }
          end
        end
      end
      params[:include] = "positions"
    end

    it "works" do
      render
      expect(included("positions").map(&:id)).to eq([2, 1])
    end
  end

  context "when class option given" do
    before do
      resource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      params[:include] = "positions"
    end

    it "works" do
      render
      expect(included("positions").map(&:id)).to eq([2, 1])
    end
  end

  describe "has_many macro" do
    before do
      resource.class_eval do
        has_many :positions do
          scope do |employee_ids|
            {
              type: :positions,
              conditions: {employee_id: employee_ids}
            }
          end
        end
      end
      params[:include] = "positions"
    end

    it "works" do
      render
      expect(included("positions").map(&:id)).to eq([1, 2])
    end

    context "when custom foreign key given" do
      before do
        PORO::DB.data[:positions][0] = {id: 1, e_id: 1}
        PORO::DB.data[:positions][1] = {id: 2, e_id: 1}

        resource.class_eval do
          has_many :positions, foreign_key: :e_id do
            scope do |employee_ids|
              {
                type: :positions,
                conditions: {e_id: employee_ids}
              }
            end
          end
        end
        params[:include] = "positions"
      end

      it "is used" do
        render
        expect(included("positions").map(&:id)).to eq([1, 2])
      end
    end
  end

  describe "belongs_to macro" do
    let(:resource) do
      Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end
      end
    end

    let(:base_scope) { {type: :positions} }

    before do
      resource.class_eval do
        belongs_to :employee do
          scope do |employee_ids|
            {
              type: :employees,
              conditions: {id: employee_ids}
            }
          end
        end
      end
      params[:include] = "employee"
    end

    it "works" do
      render
      expect(included("employees").map(&:id)).to eq([1])
    end
  end

  # Note we're seeding 2 bios
  describe "has_one macro" do
    before do
      resource.class_eval do
        has_one :bio do
          scope do |employee_ids|
            {
              type: :bios,
              conditions: {employee_id: employee_ids}
            }
          end
        end
      end
      params[:include] = "bio"
    end

    it "works" do
      render
      expect(included("bios").map(&:id)).to eq([1])
    end
  end

  describe "many_to_many macro" do
    before do
      resource.class_eval do
        many_to_many :teams, foreign_key: {team_memberships: :employee_id} do
          # fake the logic to join tables etc
          scope do |employee_ids|
            {
              type: :teams,
              conditions: {id: [1, 2]}
            }
          end
        end
      end
      params[:include] = "teams"
    end

    it "works" do
      render
      expect(included("teams").map(&:id)).to eq([1, 2])
    end
  end

  describe "polymorphic_belongs_to macro" do
    let!(:visa) { PORO::Visa.create }
    let!(:mastercard) { PORO::Mastercard.create }
    let!(:paypal) { PORO::Paypal.create }
    let!(:employee2) do
      PORO::Employee.create credit_card_type: "Mastercard",
        credit_card_id: mastercard.id
    end
    let!(:employee3) do
      PORO::Employee.create credit_card_type: "Paypal",
        credit_card_id: paypal.id
    end

    before do
      employee.update_attributes credit_card_type: "Visa",
        credit_card_id: visa.id
      params[:include] = "credit_card"
    end

    def credit_card(index)
      json["data"][index]["relationships"]["credit_card"]["data"]
    end

    def assert_correct_response
      expect(credit_card(0)).to eq({
        "type" => "visas", "id" => "1"
      })
      expect(credit_card(1)).to eq({
        "type" => "mastercards", "id" => "1"
      })
      expect(included[0].jsonapi_type).to eq("visas")
      expect(included[0].relationships).to eq({
        "visa_rewards" => {"meta" => {"included" => false}}
      })
      expect(included[1].jsonapi_type).to eq("mastercards")
      expect(included[1].relationships).to eq({
        "commercials" => {"meta" => {"included" => false}}
      })
    end

    context "when defaults" do
      before do
        resource.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type, except: [:Paypal]) do
            on(:Visa)
            on(:Mastercard)
          end
        end
      end

      it "works" do
        render
        assert_correct_response
      end

      it "does not register children on the resource, but the parent sideload" do
        expect(resource.sideloads).to_not have_key(:visa)
        expect(resource.sideloads[:credit_card].children[:visa])
          .to be_a(Graphiti::Sideload::BelongsTo)
      end

      it "creates child sideloads correctly" do
        sl = resource.sideloads[:credit_card]
        children = sl.children.values
        expect(children.map(&:group_name)).to match_array([:Visa, :Mastercard])
        expect(children).to all(be_polymorphic_child)
        expect(children.map(&:parent)).to all(eq(sl))
      end

      it "creates a polymorphic, abstract resource" do
        sl = resource.sideload(:credit_card)
        expect(sl.resource).to be_polymorphic
        expect(sl.resource.class).to be_abstract_class
        expect(sl.resource.polymorphic).to match_array([
          sl.children[:visa].resource_class,
          sl.children[:mastercard].resource_class
        ])
      end

      it "does not create or require excluded types" do
        sl = resource.sideload(:credit_card)
        expect(sl.resource).to be_polymorphic
        expect(sl.resource.class).to be_abstract_class
        expect(sl.children.keys).not_to include(:paypal)
      end
    end

    context "when linking unknown type" do
      before do
        Graphiti::Resource.autolink = true
        params.delete(:include)
        params[:links] = true
        resource.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type) do
            on(:Visa)
            on(:Mastercard)
          end
        end
      end

      after do
        Graphiti::Resource.autolink = false
      end

      it "does not blow up" do
        render
        expect(d[0].link(:credit_card, :related)).to be_present
        expect(d[1].link(:credit_card, :related)).to be_present
        expect(d[2].link(:credit_card, :related)).to be_nil
      end
    end

    context "with except option specified" do
      before do
        resource.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type, except: [:Mastercard, :Paypal]) do
            on(:Visa)
          end
        end

        params[:include] = "credit_card"
      end

      it "does not add excluded relationships" do
        render
        expect(included.map(&:jsonapi_type)).to contain_exactly("visas")
      end
    end

    context "with only option specified" do
      before do
        resource.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type, only: [:Visa, :Mastercard]) do
            on(:Visa)
            on(:Mastercard)
          end
        end

        params[:include] = "credit_card"
      end

      it "only builds specified relationships" do
        render
        expect(included.map(&:jsonapi_type)).to contain_exactly("visas", "mastercards")
      end
    end

    context "when multiple macros defined on the same keys" do
      before do
        resource.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type, except: [:Paypal]) do
            on(:Visa)
            on(:Mastercard)
          end
        end

        resource.polymorphic_belongs_to :payment_processor do
          group_by(:credit_card_type, only: [:Paypal]) do
            on(:Paypal).belongs_to :payment_processor,
              resource: PORO::PaypalResource,
              foreign_key: :credit_card_id
          end
        end

        params[:include] = "credit_card,payment_processor"
      end

      def payment_processor(index)
        json["data"][index]["relationships"]["payment_processor"]["data"]
      end

      def assert_correct_response
        expect(credit_card(0)).to eq({
          "type" => "visas", "id" => "1"
        })
        expect(credit_card(1)).to eq({
          "type" => "mastercards", "id" => "1"
        })
        expect(payment_processor(2)).to eq({
          "type" => "paypals", "id" => "1"
        })
        expect(included[0].jsonapi_type).to eq("visas")
        expect(included[0].relationships).to eq({
          "visa_rewards" => {"meta" => {"included" => false}}
        })
        expect(included[1].jsonapi_type).to eq("mastercards")
        expect(included[1].relationships).to eq({
          "commercials" => {"meta" => {"included" => false}}
        })
        expect(included[2].jsonapi_type).to eq("paypals")
        expect(included[2].relationships).to be_nil
      end

      it "works" do
        render
        assert_correct_response
      end
    end

    context "when custom class is specified" do
      let(:custom) do
        Class.new(Graphiti::Sideload) do
          def type
            :belongs_to
          end
        end
      end

      it "is used" do
        sl = resource.polymorphic_belongs_to :credit_card, class: custom
        expect(sl).to be_a(custom)
      end
    end

    context "when adapter class is specified" do
      let(:custom) do
        Class.new(Graphiti::Sideload) do
          def type
            :belongs_to
          end
        end
      end

      it "is used" do
        expect(resource.adapter).to receive(:sideloading_classes)
          .and_return(polymorphic_belongs_to: custom)
        sl = resource.polymorphic_belongs_to :credit_card
        expect(sl).to be_a(custom)
      end
    end

    context "when custom FK" do
      before do
        resource.polymorphic_belongs_to :credit_card, foreign_key: :cc_id do
          group_by(:credit_card_type, except: [:Paypal]) do
            on(:Visa)
            on(:Mastercard)
          end
        end

        employee.update_attributes(cc_id: visa.id, credit_card_id: nil)
        employee2.update_attributes(cc_id: mastercard.id, credit_card_id: nil)
      end

      it "is respected" do
        render
        assert_correct_response
      end
    end

    context "when customized child relationship" do
      let(:special_visa_resource) do
        Class.new(PORO::VisaResource) do
          self.type = :special_visas
        end
      end

      before do
        special_visa = special_visa_resource
        resource.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type, except: [:Paypal]) do
            on(:Visa).belongs_to :visa, resource: special_visa
            on(:Mastercard)
          end
        end
      end

      it "is respected" do
        render
        expect(credit_card(0)).to eq({
          "type" => "special_visas", "id" => "1"
        })
      end
    end
  end

  context "when the associated resource has default pagination" do
    before do
      resource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      resource.class_eval do
        self.default_page_size = 1
      end
      params[:include] = "positions"
    end

    it "is ignored for sideloads" do
      render
      expect(included("positions").map(&:id)).to match_array([1, 2])
    end
  end

  context "when nesting sideloads" do
    before do
      stub_const(
        "Graphiti::Scope::GLOBAL_THREAD_POOL_EXECUTOR",
        Concurrent::Promises.delay do
          Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: 1, fallback_policy: :caller_runs)
        end
      )

      PORO::EmployeeResource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      PORO::PositionResource.class_eval do
        belongs_to :department do
          scope do |department_ids|
            {
              type: :departments,
              conditions: {id: department_ids}
            }
          end
        end
      end
      params[:include] = "positions.department"
    end

    it "works" do
      render
      expect(included("positions").map(&:id)).to match_array([1, 2])
      expect(included("departments").map(&:id)).to match_array([1, 2])
    end
  end

  context "when passing pagination params for > 1 parent objects" do
    before do
      PORO::DB.data[:employees] << {id: 999}
      resource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      params[:include] = "positions"
      params[:page] = {
        positions: {size: 1}
      }
    end

    it "raises an error, because this is difficult/impossible" do
      expect {
        render
      }.to raise_error(Graphiti::Errors::UnsupportedPagination)
    end
  end

  context "when passing pagination params for only 1 object" do
    before do
      resource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      params[:include] = "positions"
      params[:page] = {size: 1}
    end

    it "works" do
      params[:page][:positions] = {size: 1}
      render
      expect(included("positions").map(&:id)).to match_array([2])
    end

    context "with offset" do
      before do
        params[:page][:positions] = {offset: 1}
      end

      it "works" do
        render
        expect(included("positions").map(&:id)).to match_array([1])
      end
    end

    context "with cursor" do
      before do
        cursor = Base64.encode64({offset: 1}.to_json)
        params[:page][:positions] = {after: cursor}
      end

      it "works" do
        render
        expect(included("positions").map(&:id)).to match_array([1])
      end
    end
  end

  context "when resource sideloading" do
    let(:position_resource) do
      Class.new(PORO::PositionResource) do
        attribute :employee_id, :integer, only: [:filterable]

        def base_scope
          {type: :positions}
        end

        def self.name
          "PORO::PositionResource"
        end
      end
    end

    context "via has_many" do
      before do
        resource.has_many :positions, resource: position_resource
        params[:include] = "positions"
      end

      it "works" do
        render
        expect(included("positions").map(&:id)).to match_array([1, 2])
      end

      context "but primary key is nil" do
        let(:has_many_opts) do
          {
            resource: position_resource,
            primary_key: :classification_id
          }
        end

        before do
          resource.has_many :positions, has_many_opts
        end

        it "does not fire the query" do
          expect(position_resource).to_not receive(:_all)
          render
        end

        context "but params customization" do
          before do
            ids = [position1.id, position2.id]
            resource.has_many :positions, has_many_opts do
              params do |hash|
                hash[:filter] = {id: ids}
              end

              assign do |employees, positions|
                employees[0].positions = positions
              end
            end
          end

          it "works" do
            render
            sl = d[0].sideload(:positions)
            expect(sl.map(&:id)).to eq([position1.id, position2.id])
          end
        end
      end

      context "but primary key is []" do
        before do
          resource.has_many :positions,
            resource: position_resource,
            primary_key: :classification_id
          employee.update_attributes(classification_id: [])
        end

        it "does not fire the query" do
          expect(position_resource).to_not receive(:_all)
          render
        end
      end

      context 'but primary key is [""]' do
        before do
          resource.has_many :positions,
            resource: position_resource,
            primary_key: :classification_id
          employee.update_attributes(classification_id: [""])
        end

        it "does not fire the query" do
          expect(position_resource).to_not receive(:_all)
          render
        end
      end

      context "and params customization" do
        before do
          resource.has_many :positions, resource: position_resource do
            params do |hash|
              hash[:filter][:id] = 2
            end
          end
        end

        it "is respected" do
          render
          expect(included("positions").map(&:id)).to match_array([2])
        end
      end

      context "and pre_load customization" do
        before do
          resource.has_many :positions, resource: position_resource do
            pre_load do |proxy|
              proxy.scope.object[:conditions][:id] = 2
            end
          end
        end

        it "is respected" do
          render
          expect(included("positions").map(&:id)).to match_array([2])
        end
      end
    end

    context "via_belongs_to" do
      let(:resource) { position_resource }
      let(:base_scope) { {type: :positions} }

      let(:department_resource) do
        Class.new(PORO::DepartmentResource) do
          self.model = PORO::Department

          def base_scope
            {type: :departments}
          end

          def self.name
            "PORO::DepartmentResource"
          end
        end
      end

      before do
        position_resource.belongs_to :department, resource: department_resource
        params[:include] = "department"
      end

      it "works" do
        render
        expect(included("departments").map(&:id)).to match_array([1, 2])
      end

      context "but the foreign key is nil" do
        before do
          position1.update_attributes(department_id: nil)
          position2.update_attributes(department_id: nil)
        end

        it "returns nil without querying" do
          expect(department_resource).to_not receive(:all)
          render
          expect(d[0].sideload("department")).to be_nil
          expect(d[1].sideload("department")).to be_nil
        end

        context "but params customization" do
          let!(:department) { PORO::Department.create }
          let(:filter_param) do
            ->(id) { {id: id} }
          end

          before do
            dept_id = department.id
            param = filter_param
            position_resource.belongs_to :department, resource: department_resource do
              params do |hash|
                hash[:filter] = param.call(dept_id)
              end

              assign_each do |position, departments|
                position.department = departments[0]
              end
            end
          end

          it "works" do
            render
            sl = d[0].sideload(:department)
            expect(sl.id).to eq(department.id)
          end

          context "with nested filter" do
            let(:filter_param) do
              ->(id) { {id: {eq: id}} }
            end

            it "works" do
              render
              sl = d[0].sideload(:department)
              expect(sl.id).to eq(department.id)
            end
          end
        end
      end

      context "and params customization" do
        before do
          position_resource.belongs_to :department, resource: department_resource do
            params do |hash|
              hash[:filter][:id] = 2
            end
          end
        end

        it "is respected" do
          render
          expect(included("departments").map(&:id)).to match_array([2])
        end
      end

      context "and pre_load customization" do
        before do
          position_resource.belongs_to :department, resource: department_resource do
            pre_load do |proxy|
              proxy.scope.object[:conditions][:id] = 2
            end
          end
        end

        it "is respected" do
          render
          expect(included("departments").map(&:id)).to match_array([2])
        end
      end
    end

    context "via has_one" do
      let(:bio_resource) do
        Class.new(PORO::BioResource) do
          self.model = PORO::Bio
          attribute :employee_id, :integer, only: [:filterable]

          def base_scope
            {type: :bios}
          end

          def self.name
            "PORO::BioResource"
          end
        end
      end

      before do
        resource.has_one :bio, resource: bio_resource
        params[:include] = "bio"
      end

      it "works" do
        render
        expect(included("bios").map(&:id)).to match_array([1])
      end

      context "and params customization" do
        before do
          resource.has_one :bio, resource: bio_resource do
            params do |hash|
              hash[:filter][:id] = 2
            end
          end
        end

        it "is respected" do
          render
          expect(included("bios").map(&:id)).to match_array([2])
        end
      end

      context "and pre_load customization" do
        before do
          resource.has_one :bio, resource: bio_resource do
            pre_load do |proxy|
              proxy.scope.object[:conditions][:id] = 2
            end
          end
        end

        it "is respected" do
          render
          expect(included("bios").map(&:id)).to match_array([2])
        end
      end
    end
  end

  describe "sideloading the same entity twice" do
    let(:department_resource) do
      Class.new(PORO::DepartmentResource) do
        def base_scope
          {type: :departments}
        end

        def self.name
          "PORO::DepartmentResource"
        end
      end
    end

    let(:position_resource) do
      Class.new(PORO::PositionResource) do
        attribute :employee_id, :integer, only: [:filterable]

        def base_scope
          {type: :positions}
        end

        def self.name
          "PORO::PositionResource"
        end
      end
    end

    before do
      PORO::Position.class_eval do
        def department
          @department ||= PORO::Department.new(PORO::DB.data[:departments][0])
        end
      end

      resource.has_one :current_position, resource: position_resource
      resource.has_many :positions, resource: position_resource
      position_resource.belongs_to :department, resource: department_resource
      params[:include] = "current_position.department,positions"
    end

    it "only appears once in the payload" do
      render
      included = json["included"]
      pos1 = included.select { |i|
        i["type"] == "positions" && i["id"] == position1.id.to_s
      }
      expect(pos1.length).to eq(1)
    end

    it "has all correct assocations" do
      render
      sl = d[0].sideload(:current_position)
      expect(sl.id).to eq(1)
      expect(sl.jsonapi_type).to eq("positions")
      expect(sl.sideload(:department)).to be_present
    end

    # This will fetch a department that will not have a @__graphiti_serializer
    # assigned, because it wasn't part of the query plan. This should not cause
    # an error; we should drop the data
    it "does not try to calculate sideloads twice" do
      expect {
        render
      }.to_not raise_error
    end

    describe "across requests" do
      it "uses a different sideloaded resource" do
        ctx = double(current_user: :admin)
        sl1 = Graphiti.with_context ctx do
          resource.all(params).query.sideloads.values[0].resource
        end

        sl2 = Graphiti.with_context ctx do
          resource.all(params).query.sideloads.values[0].resource
        end

        expect(sl1).to_not be sl2
      end
    end
  end

  context "when a required filter on the sideloaded resource" do
    xit "should maybe raise, not sure yet. that is why this spec is spending" do
    end
  end
end
