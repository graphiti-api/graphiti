require 'spec_helper'

RSpec.describe JsonapiCompliable::Sideload::HasMany do
  let(:parent_resource_class) { PORO::EmployeeResource }
  let(:opts) { { parent_resource: parent_resource_class } }
  let(:name) { :positions }
  let(:instance) { described_class.new(name, opts) }

  describe '#assign_each' do
    let!(:employee) { PORO::Employee.new(id: 1) }
    let!(:position1) { PORO::Position.new(id: 1, employee_id: 1) }
    let!(:position2) { PORO::Position.new(id: 2, employee_id: 2) }
    let!(:position3) { PORO::Position.new(id: 3, employee_id: 1) }
    let!(:positions) { [position1, position2, position3] }

    it 'selects correct children' do
      relevant = instance.assign_each(employee, positions)
      expect(relevant).to eq([position1, position3])
    end
  end

  describe '#assign' do
    let!(:employee1) { PORO::Employee.new(id: 1) }
    let!(:employee2) { PORO::Employee.new(id: 2) }
    let!(:position1) { PORO::Position.new(id: 1, employee_id: 1) }
    let!(:position2) { PORO::Position.new(id: 2, employee_id: 2) }
    let!(:position3) { PORO::Position.new(id: 3, employee_id: 1) }
    let!(:employees) { [employee1, employee2] }
    let!(:positions) { [position1, position2, position3] }

    it 'associates correctly' do
      instance.assign(employees, positions)
      expect(employee1.positions).to eq([position1, position3])
      expect(employee2.positions).to eq([position2])
    end
  end
end
