require 'spec_helper'

RSpec.describe JsonapiCompliable::Sideload do
  let(:parent_resource_class) do
    Class.new(PORO::EmployeeResource) do
      def self.name;'PORO::EmployeeResource';end
    end
  end
  let(:resource_class) do
    Class.new(PORO::PositionResource) do
      self.model = PORO::Position
      def self.name;'PORO::PositionResource';end
    end
  end
  let(:opts) do
    {
      parent_resource: parent_resource_class,
      resource: resource_class
    }
  end
  let(:name) { :foo }
  let(:instance) { Class.new(described_class).new(name, opts) }

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
    let(:name) { :positions }

    before do
      opts.delete(:resource)
    end

    it 'is inferred by default' do
      expect(instance.resource_class).to eq(PORO::PositionResource)
    end

    context 'when no class in that namespace' do
      before do
        stub_const('PositionResource', PORO::PositionResource)
        hide_const('PORO::PositionResource')
      end

      it 'falls back to non-namespaced' do
        expect(instance.resource_class).to eq(PositionResource)
      end
    end

    context 'when not found by inferrence' do
      let(:name) { :foo }

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
        opts[:parent_resource].model = SideloadSpec::Employee
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
        opts[:parent_resource].model = SideloadSpecEmployee
      end

      it 'derives a to_many foreign key from the resource model' do
        expect(instance.infer_foreign_key).to eq(:sideload_spec_employee_id)
      end
    end
  end

  describe '#associate' do
    before do
      opts[:type] = :has_many
    end

    it 'delegates to parent resource' do
      parent, child = 'a', 'b'
      expect(instance.parent_resource).to receive(:associate)
        .with(parent, child, :foo, :has_many)
      instance.associate(parent, child)
    end

    context 'when given the :as option' do
      before do
        opts[:as] = :bar
      end

      it 'is passed as the association name' do
        parent, child = 'a', 'b'
        expect(instance.parent_resource).to receive(:associate)
          .with(parent, child, :bar, :has_many)
        instance.associate(parent, child)
      end
    end
  end

  describe '#disassociate' do
    before do
      opts[:type] = :has_many
    end

    it 'delegates to parent resource' do
      parent, child = 'a', 'b'
      expect(instance.parent_resource).to receive(:disassociate)
        .with(parent, child, :foo, :has_many)
      instance.disassociate(parent, child)
    end

    context 'when given the :as option' do
      before do
        opts[:as] = :bar
      end

      it 'is passed as the association name' do
        parent, child = 'a', 'b'
        expect(instance.parent_resource).to receive(:disassociate)
          .with(parent, child, :bar, :has_many)
        instance.disassociate(parent, child)
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
      before do
        opts.delete(:resource)
      end

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

  describe '.params' do
    before do
      instance.class.params do |hash, parents, query|
        hash[:parents] = parents
        hash[:query] = query
      end
    end

    it 'sets params proc' do
      hash, parents, query = {}, [double('parent')], double('query')
      instance.params_proc.call(hash, parents, query)
      expect(hash).to eq(parents: parents, query: query)
    end
  end

  describe '.pre_load' do
    before do
      instance.class.pre_load do |proxy|
        proxy[:foo] = 'bar'
      end
    end

    it 'sets pre_load proc' do
      hash = {}
      instance.pre_load_proc.call(hash)
      expect(hash).to eq(foo: 'bar')
    end
  end


  describe '#association_name' do
    it 'defaults to name' do
      expect(instance.association_name).to eq(:foo)
    end

    context 'when given :as option' do
      before do
        opts[:as] = :bar
      end

      it 'uses the option' do
        expect(instance.association_name).to eq(:bar)
      end
    end
  end

  describe '#load' do
    let(:params) { {} }
    let(:query) { JsonapiCompliable::Query.new(instance.resource, params) }
    let(:parents) { [double, double] }
    let(:results) { [double('result')] }

    before do
      allow(instance).to receive(:load_params) { { foo: 'bar' } }
      allow(resource_class).to receive(:_all) { results }
    end

    it 'uses base scope' do
      base = double
      allow(instance).to receive(:base_scope) { base }
      expect(resource_class).to receive(:_all)
        .with(anything, anything, base)
      instance.load(parents, query)
    end

    it 'uses load params' do
      expect(resource_class).to receive(:_all)
        .with({ foo: 'bar' }, anything, nil)
      instance.load(parents, query)
    end

    it 'passes internal load options' do
      expected = {
        default_paginate: false,
        sideload_parent_length: 2,
        after_resolve: anything
      }
      expect(resource_class).to receive(:_all)
        .with(anything, expected, nil)
      instance.load(parents, query)
    end

    it 'returns records' do
      records = instance.load(parents, query)
      expect(records).to eq(results)
    end

    context 'when params customization' do
      before do
        instance.class.params do |hash, parents, query|
          hash[:a] = parents
          hash[:b] = query
        end
      end

      it 'is respected' do
        expected = {
          foo: 'bar',
          a: parents,
          b: query
        }
        expect(resource_class).to receive(:_all)
          .with(expected, anything, nil)
        instance.load(parents, query)
      end
    end

    context 'when pre_load customization' do
      let(:parents) { [] }

      before do
        allow(instance).to receive(:load_params) { { sort: '-id' } }
        allow(resource_class).to receive(:_all).and_call_original
        instance.class.pre_load do |proxy|
          proxy.scope.object[:modified] = true
        end
      end

      it 'is respected' do
        expect(PORO::DB).to receive(:all).with({
          modified: true, sort: [{ id: :desc }]
        }).and_return([])
        instance.load(parents, query)
      end
    end
  end
end
