require 'spec_helper'

RSpec.describe JsonapiCompliable::Sideload::HasOne do
  let(:parent_resource_class) { PORO::EmployeeResource }
  let(:opts) { { parent_resource: parent_resource_class } }
  let(:name) { :bio }
  let(:instance) { described_class.new(name, opts) }

  describe '#assign_each' do
    let!(:employee) { PORO::Employee.new(id: 1) }
    let!(:bio1) { PORO::Bio.new(id: 1, employee_id: 2) }
    let!(:bio2) { PORO::Bio.new(id: 2, employee_id: 1) }
    let!(:bio3) { PORO::Bio.new(id: 3, employee_id: 1) }
    let!(:bios) { [bio1, bio2, bio3] }

    it 'assigns the first relevant child' do
      relevant = instance.assign_each(employee, bios)
      expect(relevant).to eq(bio2)
    end
  end

  describe '#assign' do
    let!(:employee1) { PORO::Employee.new(id: 1) }
    let!(:employee2) { PORO::Employee.new(id: 2) }
    let!(:bio1) { PORO::Bio.new(id: 1, employee_id: 2) }
    let!(:bio2) { PORO::Bio.new(id: 2, employee_id: 1) }
    let!(:bio3) { PORO::Bio.new(id: 3, employee_id: 1) }
    let!(:employees) { [employee1, employee2] }
    let!(:bios) { [bio1, bio2, bio3] }

    it 'associates correctly' do
      instance.assign(employees, bios)
      expect(employee1.bio).to eq(bio2)
      expect(employee2.bio).to eq(bio1)
    end
  end
end
