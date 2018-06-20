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
      def scope(employees)
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

  context 'when a required filter on the sideloaded resource' do
    xit 'should maybe raise, not sure yet. that is why this spec is spending' do
    end
  end
end
