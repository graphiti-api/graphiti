require 'spec_helper'

RSpec.describe 'sideloading' do
  include JsonHelpers
  include_context 'resource testing'
  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        'PORO::EmployeeResource'
      end
    end
  end
  let(:base_scope) { { type: :employees } }

  module Sideloading
    class CustomPositionResource < ::PORO::PositionResource
      self.default_sort = [{ id: :desc }]
    end

    class PositionSideload < ::JsonapiCompliable::Sideload::HasMany
      scope do |employees|
        { type: :positions, sort: [{ id: :desc }] }
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

  context 'when basic manual sideloading' do
    before do
      resource.class_eval do
        allow_sideload :positions, type: :has_many do
          scope do |employees|
            {
              type: :positions,
              conditions: { employee_id: employees.map(&:id) }
            }
          end

          assign_each do |employee, positions|
            positions.select { |p| p.employee_id == employee.id }
          end
        end
      end
    end

    it 'works' do
      params[:include] = 'positions'
      render
      expect(ids_for('positions')).to eq([1, 2])
    end

    context 'and deep querying' do
      before do
        params[:include] = 'positions'
        params[:sort] = '-positions.id'
      end

      it 'works' do
        render
        expect(ids_for('positions')).to eq([2, 1])
      end
    end
  end

  context 'when using .assign instead of .assign_each' do
    before do
      resource.class_eval do
        allow_sideload :positions, type: :has_many do
          scope do |employees|
            {
              type: :positions,
              conditions: { employee_id: employees.map(&:id) }
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
      params[:include] = 'positions'
    end

    it 'works' do
      render
      expect(ids_for('positions')).to eq([1, 2])
    end
  end

  context 'when custom resource option given' do
    before do
      resource.class_eval do
        allow_sideload :positions, type: :has_many, resource: Sideloading::CustomPositionResource do
          scope do |employees|
            {
              type: :positions,
              conditions: { employee_id: employees.map(&:id) }
            }
          end

          assign_each do |employee, positions|
            positions.select { |p| p.employee_id == employee.id }
          end
        end
      end
      params[:include] = 'positions'
    end

    it 'works' do
      render
      expect(ids_for('positions')).to eq([2, 1])
    end
  end

  context 'when class option given' do
    before do
      resource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      params[:include] = 'positions'
    end

    it 'works' do
      render
      expect(ids_for('positions')).to eq([2, 1])
    end
  end

  describe 'has_many macro' do
    before do
      resource.class_eval do
        has_many :positions do
          scope do |employees|
            {
              type: :positions,
              conditions: { employee_id: employees.map(&:id) }
            }
          end
        end
      end
      params[:include] = 'positions'
    end

    it 'works' do
      render
      expect(ids_for('positions')).to eq([1, 2])
    end

    context 'when custom foreign key given' do
      before do
        PORO::DB.data[:positions][0] = { id: 1, e_id: 1  }
        PORO::DB.data[:positions][1] = { id: 2, e_id: 1  }

        resource.class_eval do
          has_many :positions, foreign_key: :e_id do
            scope do |employees|
              {
                type: :positions,
                conditions: { e_id: employees.map(&:id) }
              }
            end
          end
        end
        params[:include] = 'positions'
      end

      it 'is used' do
        render
        expect(ids_for('positions')).to eq([1, 2])
      end
    end
  end

  describe 'belongs_to macro' do
    let(:resource) do
      Class.new(PORO::PositionResource) do
        def self.name
          'PORO::PositionResource'
        end
      end
    end

    let(:base_scope) { { type: :positions } }

    before do
      resource.class_eval do
        belongs_to :employee do
          scope do |positions|
            {
              type: :employees,
              conditions: { id: positions.map(&:employee_id) }
            }
          end
        end
      end
      params[:include] = 'employee'
    end

    it 'works' do
      render
      expect(ids_for('employees')).to eq([1])
    end
  end

  # Note we're seeding 2 bios
  describe 'has_one macro' do
    before do
      resource.class_eval do
        has_one :bio do
          scope do |employees|
            {
              type: :bios,
              conditions: { employee_id: employees.map(&:id) }
            }
          end
        end
      end
      params[:include] = 'bio'
    end

    it 'works' do
      render
      expect(ids_for('bios')).to eq([1])
    end
  end

  describe 'many_to_many macro' do
    before do
      resource.class_eval do
        many_to_many :teams, foreign_key: { team_memberships: :employee_id } do
          # fake the logic to join tables etc
          scope do |employees|
            {
              type: :teams,
              conditions: { id: [1, 2] }
            }
          end
        end
      end
      params[:include] = 'teams'
    end

    it 'works' do
      render
      expect(ids_for('teams')).to eq([1, 2])
    end
  end

  describe 'polymorphic_belongs_to macro' do
    let!(:visa) { PORO::Visa.create }
    let!(:mastercard) { PORO::Mastercard.create }
    let!(:employee2) do
      PORO::Employee.create credit_card_type: 'Mastercard',
          credit_card_id: mastercard.id
    end

    before do
      employee.update_attributes credit_card_type: 'Visa',
        credit_card_id: visa.id
      params[:include] = 'credit_card'
    end

    def credit_card(index)
      json['data'][index]['relationships']['credit_card']['data']
    end

    def included(index)
      json['included'][index]
    end

    def assert_correct_response
      expect(credit_card(0)).to eq({
        'type' => 'visas', 'id' => '1'
      })
      expect(credit_card(1)).to eq({
        'type' => 'mastercards', 'id' => '1'
      })
      expect(included(0)['type']).to eq('visas')
      expect(included(0)['relationships']).to eq({
        'visa_rewards' => { 'meta' => { 'included' => false } }
      })
      expect(included(1)['type']).to eq('mastercards')
      expect(included(1)).to_not have_key('relationships')
    end

    context 'when defaults' do
      before do
        resource.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type) do
            on(:Visa)
            on(:Mastercard)
          end
        end
      end

      it 'works' do
        render
        assert_correct_response
      end

      it 'does not register children on the resource, but the parent sideload' do
        expect(resource.sideloads).to_not have_key(:visa)
        expect(resource.sideloads[:credit_card].children[:visa])
          .to be_a(JsonapiCompliable::Sideload::BelongsTo)
      end

      it 'creates child sideloads correctly' do
        sl = resource.sideloads[:credit_card]
        children = sl.children.values
        expect(children.map(&:group_name)).to match_array([:Visa, :Mastercard])
        expect(children).to all(be_polymorphic_child)
        expect(children.map(&:parent)).to all(eq(sl))
      end

      it 'creates a polymorphic, abstract resource' do
        sl = resource.sideload(:credit_card)
        expect(sl.resource).to be_polymorphic
        expect(sl.resource.class).to be_abstract_class
        expect(sl.resource.polymorphic).to match_array([
          sl.children[:visa].resource_class,
          sl.children[:mastercard].resource_class
        ])
      end
    end

    context 'when custom class is specified' do
      let(:custom) { Class.new(JsonapiCompliable::Sideload) }

      it 'is used' do
        sl = resource.polymorphic_belongs_to :credit_card, class: custom
        expect(sl).to be_a(custom)
      end
    end

    context 'when adapter class is specified' do
      let(:custom) { Class.new(JsonapiCompliable::Sideload) }

      it 'is used' do
        expect(resource.adapter).to receive(:sideloading_classes)
          .and_return(polymorphic_belongs_to: custom)
        sl = resource.polymorphic_belongs_to :credit_card
        expect(sl).to be_a(custom)
      end
    end

    context 'when custom FK' do
      before do
        resource.polymorphic_belongs_to :credit_card, foreign_key: :cc_id do
          group_by(:credit_card_type) do
            on(:Visa)
            on(:Mastercard)
          end
        end

        employee.update_attributes(cc_id: visa.id, credit_card_id: nil)
        employee2.update_attributes(cc_id: mastercard.id, credit_card_id: nil)
      end

      it 'is respected' do
        render
        assert_correct_response
      end
    end

    context 'when customized child relationship' do
      let(:special_visa_resource) do
        Class.new(PORO::VisaResource) do
          self.type = :special_visas
        end
      end

      before do
        _resource = special_visa_resource
        resource.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type) do
            on(:Visa).belongs_to :visa, resource: _resource
            on(:Mastercard)
          end
        end
      end

      it 'is respected' do
        render
        expect(credit_card(0)).to eq({
          'type' => 'special_visas', 'id' => '1'
        })
      end
    end
  end

  context 'when the associated resource has default pagination' do
    before do
      resource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      resource.class_eval do
        self.default_page_size = 1
      end
      params[:include] = 'positions'
    end

    it 'is ignored for sideloads' do
      render
      expect(ids_for('positions')).to match_array([1, 2])
    end
  end

  context 'when nesting sideloads' do
    before do
      PORO::EmployeeResource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      PORO::PositionResource.class_eval do
        belongs_to :department do
          scope do |positions|
            {
              type: :departments,
              conditions: { id: positions.map(&:department_id) }
            }
          end
        end
      end
      params[:include] = 'positions.department'
    end

    it 'works' do
      render
      expect(ids_for('positions')).to match_array([1, 2])
      expect(ids_for('departments')).to match_array([1, 2])
    end
  end

  context 'when passing pagination params for > 1 parent objects' do
    before do
      PORO::DB.data[:employees] << { id: 999  }
      resource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      params[:include] = 'positions'
      params[:page] = {
        positions: { size: 1 }
      }
    end

    it 'raises an error, because this is difficult/impossible' do
      expect {
        render
      }.to raise_error(JsonapiCompliable::Errors::UnsupportedPagination)
    end
  end

  context 'when passing pagination params for only 1 object' do
    before do
      resource.class_eval do
        allow_sideload :positions, class: Sideloading::PositionSideload
      end
      params[:include] = 'positions'
      params[:page] = {
        size: 1,
        positions: { size: 1 }
      }
    end

    it 'works' do
      render
      expect(ids_for('positions')).to match_array([2])
    end
  end

  context 'when resource sideloading' do
    let(:position_resource) do
      Class.new(PORO::PositionResource) do
        attribute :employee_id, :integer, only: [:filterable]

        def base_scope
          { type: :positions }
        end
      end
    end

    context 'via has_many' do
      before do
        resource.has_many :positions, resource: position_resource
        params[:include] = 'positions'
      end

      it 'works' do
        render
        expect(ids_for('positions')).to match_array([1, 2])
      end

      context 'and params customization' do
        before do
          resource.has_many :positions, resource: position_resource do
            params do |hash|
              hash[:filter][:id] = 2
            end
          end
        end

        it 'is respected' do
          render
          expect(ids_for('positions')).to match_array([2])
        end
      end

      context 'and pre_load customization' do
        before do
          resource.has_many :positions, resource: position_resource do
            pre_load do |proxy|
              proxy.scope.object[:conditions][:id] = 2
            end
          end
        end

        it 'is respected' do
          render
          expect(ids_for('positions')).to match_array([2])
        end
      end
    end

    context 'via_belongs_to' do
      let(:resource) { position_resource }
      let(:base_scope) { { type: :positions } }

      let(:department_resource) do
        Class.new(PORO::DepartmentResource) do
          self.model = PORO::Department

          def base_scope
            { type: :departments }
          end
        end
      end

      before do
        position_resource.belongs_to :department, resource: department_resource
        params[:include] = 'department'
      end

      it 'works' do
        render
        expect(ids_for('departments')).to match_array([1, 2])
      end

      context 'and params customization' do
        before do
          position_resource.belongs_to :department, resource: department_resource do
            params do |hash|
              hash[:filter][:id] = 2
            end
          end
        end

        it 'is respected' do
          render
          expect(ids_for('departments')).to match_array([2])
        end
      end

      context 'and pre_load customization' do
        before do
          position_resource.belongs_to :department, resource: department_resource do
            pre_load do |proxy|
              proxy.scope.object[:conditions][:id] = 2
            end
          end
        end

        it 'is respected' do
          render
          expect(ids_for('departments')).to match_array([2])
        end
      end
    end

    context 'via has_one' do
      let(:bio_resource) do
        Class.new(PORO::BioResource) do
          self.model = PORO::Bio
          attribute :employee_id, :integer, only: [:filterable]

          def base_scope
            { type: :bios }
          end
        end
      end

      before do
        resource.has_one :bio, resource: bio_resource
        params[:include] = 'bio'
      end

      it 'works' do
        render
        expect(ids_for('bios')).to match_array([1])
      end

      context 'and params customization' do
        before do
          resource.has_one :bio, resource: bio_resource do
            params do |hash|
              hash[:filter][:id] = 2
            end
          end
        end

        it 'is respected' do
          render
          expect(ids_for('bios')).to match_array([2])
        end
      end

      context 'and pre_load customization' do
        before do
          resource.has_one :bio, resource: bio_resource do
            pre_load do |proxy|
              proxy.scope.object[:conditions][:id] = 2
            end
          end
        end

        it 'is respected' do
          render
          expect(ids_for('bios')).to match_array([2])
        end
      end
    end
  end

  context 'when a required filter on the sideloaded resource' do
    xit 'should maybe raise, not sure yet. that is why this spec is spending' do
    end
  end
end
