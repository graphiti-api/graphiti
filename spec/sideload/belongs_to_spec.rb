require 'spec_helper'

RSpec.describe JsonapiCompliable::Sideload::BelongsTo do
  let(:parent_resource_class) { PORO::PositionResource }
  let(:resource_class) do
    Class.new(PORO::EmployeeResource) do
      self.model = PORO::Employee
    end
  end
  let(:opts) do
    {
      parent_resource: parent_resource_class,
      resource: resource_class
    }
  end
  let(:name) { :employee }
  let(:instance) { described_class.new(name, opts) }

  describe "initialize" do
    it 'accepts group name (for polymorphic children)' do
      opts[:group_name] = :mygroup
      expect(instance.group_name).to eq(:mygroup)
    end
  end

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
      expect(instance.parent_resource).to receive(:associate)
        .with(position, employee, :employee, :belongs_to)
        .and_call_original
      instance.send(:associate, position, employee)
      expect(position.employee).to eq(employee)
    end

    context 'when given :as option' do
      before do
        opts[:as] = :blah
      end

      it 'uses that as the association name' do
        expect(instance.parent_resource).to receive(:associate)
          .with(position, employee, :blah, :belongs_to)
        instance.send(:associate, position, employee)
      end
    end
  end

  describe 'infer_foreign_key' do
    let(:opts) { { resource: resource } }
    let(:resource) do
      Class.new(PORO::EmployeeResource)
    end

    subject { instance.infer_foreign_key }

    context 'when the model has a namespace' do
      before do
        resource.model = double('Model Class')
        allow(resource.model).to receive(:name) { 'PORO::FooBar' }
      end

      it { is_expected.to eq(:foo_bar_id) }
    end

    context 'when the model does not have a namespace' do
      before do
        resource.model = double('Model Class')
        allow(resource.model).to receive(:name) { 'BarFoo' }
      end

      it { is_expected.to eq(:bar_foo_id) }
    end

    context 'when a polymorphic child' do
      let(:parent) { double(foreign_key: :from_parent_id) }

      before do
        allow(instance).to receive(:polymorphic_child?) { true }
        allow(instance).to receive(:parent) { parent }
      end

      it { is_expected.to eq(:from_parent_id) }
    end
  end

  describe '#load_params' do
    let(:params) { {} }
    let(:query) { JsonapiCompliable::Query.new(instance.resource, params) }
    let(:parents) { [double(bar_id: 7), double(bar_id: 8)] }

    before do
      opts[:primary_key] = :foo_id
      opts[:foreign_key] = :bar_id
      allow(instance.resource).to receive(:_all) { [] }
    end

    it 'adds primary key filter' do
      params = instance.load_params(parents, query)
      expect(params).to eq({
        filter: { foo_id: [7, 8] }
      })
    end

    it 'includes deep query params' do
      resource_class.attribute :a, :string
      params.merge!(filter: { a: 'b' }, sort: '-id')
      result = instance.load_params(parents, query)
      expect(result).to eq({
        filter: { foo_id: [7, 8], a: 'b' },
        sort: [{ id: :desc }]
      })
    end
  end
end
