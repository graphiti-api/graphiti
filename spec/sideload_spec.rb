require 'spec_helper'

RSpec.describe JsonapiCompliable::Sideload do
  let(:parent_resource_class) { PORO::EmployeeResource }
  let(:opts) { { parent_resource: parent_resource_class } }
  let(:name) { :foo }
  let(:instance) { described_class.new(name, opts) }

  describe '#primary_key' do
    it 'defaults to id' do
      expect(instance.primary_key).to eq(:id)
    end

    context 'when passed in constructor' do
      before do
        opts[:primary_key] = :foo
      end

      it 'is used' do
        expect(instance.primary_key).to eq(:foo)
      end
    end
  end

  describe '#foreign_key' do
    it 'is inferred by default' do
      expect(instance).to receive(:infer_foreign_key) { :foo_id }
      expect(instance.foreign_key).to eq(:foo_id)
    end

    context 'when passed in constructor' do
      before do
        opts[:foreign_key] = :bar_id
      end

      it 'is used' do
        expect(instance.foreign_key).to eq(:bar_id)
      end
    end
  end

  describe '#resource_class' do
    let(:name) { 'positions' }

    before do
      opts[:parent_resource] = PORO::EmployeeResource
    end

    it 'is inferred by default' do
      expect(instance.resource_class).to eq(PORO::PositionResource)
    end

    context 'when not found by inferrence' do
      let(:name) { 'asdf' }

      it 'raises helpful error' do
        expect {
          instance.resource_class
        }.to raise_error(JsonapiCompliable::Errors::ResourceNotFound)
      end
    end

    context 'when passed in constructor' do
      before do
        opts[:resource] = PORO::EmployeeResource
      end

      it 'is used' do
        expect(instance.resource_class).to eq(PORO::EmployeeResource)
      end
    end
  end

  describe '#base_scope' do
    it 'falls back to the default' do
      expect(instance).to receive(:default_base_scope) { 'foo' }
      expect(instance.base_scope).to eq('foo')
    end

    context 'when passed in constructor' do
      before do
        opts[:base_scope] = 'bar'
      end

      it 'is used' do
        expect(instance.base_scope).to eq('bar')
      end
    end
  end

  describe '#type' do
    it 'raises helpful error for subclass' do
      expect { instance.type }.to raise_error(/Override/)
    end

    context 'when passed in constructor' do
      before do
        opts[:type] = :foo_type
      end

      it 'is used' do
        expect(instance.type).to eq(:foo_type)
      end
    end
  end

  # Infers a to_many key; override for belongs_to
  describe '#infer_foreign_key' do
    context 'when within module' do
      let(:name) { 'positions' }

      module SideloadSpec
        class Employee
        end
      end

      before do
        opts[:parent_resource] = Class.new(JsonapiCompliable::Resource)
        opts[:parent_resource].config[:model] = SideloadSpec::Employee
      end

      it 'derives a to_many foreign key from the resource model' do
        expect(instance.infer_foreign_key).to eq(:employee_id)
      end
    end

    context 'when not within module' do
      let(:name) { 'positions' }

      class SideloadSpecEmployee
      end

      before do
        opts[:parent_resource] = Class.new(JsonapiCompliable::Resource)
        opts[:parent_resource].config[:model] = SideloadSpecEmployee
      end

      it 'derives a to_many foreign key from the resource model' do
        expect(instance.infer_foreign_key).to eq(:sideload_spec_employee_id)
      end
    end
  end

  describe '#assign' do
    context 'when a to-many relationship' do
      let(:instance) { JsonapiCompliable::Sideload::HasMany.new(:positions, opts) }

      let(:employees) do
        [
          PORO::Employee.new(id: 1),
          PORO::Employee.new(id: 2)
        ]
      end

      let(:positions) do
        [
          PORO::Position.new(id: 1, employee_id: 1),
          PORO::Position.new(id: 2, employee_id: 1),
          PORO::Position.new(id: 3, employee_id: 2)
        ]
      end

      it 'associates parents and children' do # awwww
        instance.assign(employees, positions)
        expect(employees[0].positions).to eq(positions[0..1])
        expect(employees[1].positions).to eq([positions.last])
      end

      context 'when there are unassigned children' do
        let(:other) { PORO::Position.new(id: 999, employee_id: 999) }

        before do
          positions << other
        end

        it 'removes them from the child array, so that subsequent sideloads are not affected' do
          expect(positions.include?(other)).to eq(true)
          instance.assign(employees, positions)
          expect(positions.include?(other)).to eq(false)
        end
      end
    end

    context 'when a to-one relationship' do
      let(:parent_resource_class) { PORO::PositionResource }
      let(:instance) { JsonapiCompliable::Sideload::BelongsTo.new(:department, opts) }

      let(:positions) do
        [
          PORO::Position.new(id: 1, department_id: 1),
          PORO::Position.new(id: 2, department_id: 2)
        ]
      end

      let(:departments) do
        [
          PORO::Department.new(id: 1),
          PORO::Department.new(id: 2)
        ]
      end

      it 'associates parents and children' do # awwww
        instance.assign(positions, departments)
        expect(positions[0].department).to eq(departments[0])
        expect(positions[1].department).to eq(departments[1])
      end

      context 'when there are unassigned children' do
        let(:other) { PORO::Department.new }

        before do
          departments << other
        end

        it 'removes them from the child array, so that subsequent sideloads are not affected' do
          expect(departments.include?(other)).to eq(true)
          instance.assign(positions, departments)
          expect(departments.include?(other)).to eq(false)
        end
      end
    end
  end
end
