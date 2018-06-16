require 'spec_helper'

RSpec.describe JsonapiCompliable::Sideload::BelongsTo do
  let(:parent_resource_class) { PORO::PositionResource }
  let(:opts) { { parent_resource: parent_resource_class } }
  let(:name) { :employee }
  let(:instance) { described_class.new(name, opts) }

  describe '#assign_each' do
    let!(:position) { PORO::Position.new(id: 1, employee_id: 2) }
    let!(:employee1) { PORO::Position.new(id: 1) }
    let!(:employee2) { PORO::Position.new(id: 2) }
    let!(:employees) { [employee1, employee2] }

    it 'selects correct children' do
      relevant = instance.assign_each(position, employees)
      expect(relevant).to eq(employee2)
    end
  end

  describe '#assign' do
    let!(:position1) { PORO::Position.new(id: 1, employee_id: 2) }
    let!(:position2) { PORO::Position.new(id: 2, employee_id: 1) }
    let!(:employee1) { PORO::Position.new(id: 1) }
    let!(:employee2) { PORO::Position.new(id: 2) }
    let!(:positions) { [position1, position2] }
    let!(:employees) { [employee1, employee2] }

    it 'associates correctly' do
      instance.assign(positions, employees)
      expect(position1.employee).to eq(employee2)
      expect(position2.employee).to eq(employee1)
    end
  end

  describe '#associate' do
    let!(:position) { PORO::Position.new }
    let!(:employee) { PORO::Employee.new }

    it 'associates correctly, via the *parent* resource' do
      #expect(instance.parent_resource).to receive(:associate)
        #.with(employee, position, :employee, :belongs_to)
      instance.send(:associate, position, employee)
      expect(position.employee).to eq(employee)
    end
  end

  describe 'infer_foreign_key' do

  end
end
