require 'spec_helper'

RSpec.describe JsonapiCompliable::SchemaDiff do
  let(:application_resource) do
    Class.new(JsonapiCompliable::Resource) do
      self.abstract_class = true
    end
  end

  let(:resource_a) do
    Class.new(application_resource) do
      def self.name;'SchemaDiff::EmployeeResource';end

      attribute :first_name, :string
    end
  end

  let(:resource_b) do
    Class.new(resource_a)
  end

  let(:position_resource) do
    Class.new(application_resource) do
      def self.name;'SchemaDiff::PositionResource';end
    end
  end

  let(:test_context) do
    Class.new do
      include JsonapiCompliable::Context
    end.new
  end

  before do
    allow(JsonapiCompliable.config).to receive(:context_for_endpoint)
      .and_return(double(call: test_context))
  end

  let(:a_resources) { [resource_a] }
  let(:b_resources) { [resource_b] }
  let(:a) { JsonapiCompliable::Schema.generate(a_resources) }
  let(:b) { JsonapiCompliable::Schema.generate(b_resources) }

  RSpec.shared_examples 'changing attribute flag' do |flag|
    context 'from true to false' do
      before do
        resource_b.attribute :first_name, :string, { flag => false }
      end

      it 'returns error' do
        expect(diff).to eq([
          "SchemaDiff::EmployeeResource: attribute :first_name changed flag :#{flag} from true to false."
        ])
      end
    end

    context 'from false to true' do
      before do
        resource_a.attribute :first_name, :string, { flag => false }
        resource_b.attribute :first_name, :string, { flag => true }
      end

      it { is_expected.to eq([]) }
    end

    context 'from true to :guarded' do
      before do
        resource_a.attribute :first_name, :string, { flag => true }
        resource_b.attribute :first_name, :string, { flag => :admin? }
      end

      it 'returns error' do
        expect(diff).to eq([
          "SchemaDiff::EmployeeResource: attribute :first_name changed flag :#{flag} from true to \"guarded\"."
        ])
      end
    end

    context 'from false to :guarded' do
      before do
        resource_a.attribute :first_name, :string, { flag => false }
        resource_b.attribute :first_name, :string, { flag => :admin? }
      end

      it { is_expected.to eq([]) }
    end

    context 'from :guarded to true' do
      before do
        resource_a.attribute :first_name, :string, { flag => :admin? }
        resource_b.attribute :first_name, :string, { flag => true }
      end

      it { is_expected.to eq([]) }
    end

    context 'from :guarded to false' do
      before do
        resource_a.attribute :first_name, :string, { flag => :admin? }
        resource_b.attribute :first_name, :string, { flag => false }
      end

      it 'returns error' do
        expect(diff).to eq([
          "SchemaDiff::EmployeeResource: attribute :first_name changed flag :#{flag} from \"guarded\" to false."
        ])
      end
    end
  end

  describe '#compare' do
    subject(:diff) { described_class.new(a, b).compare }

    context 'when no diff' do
      it { is_expected.to eq([]) }
    end

    context 'when attribute changes type' do
      before do
        resource_b.attribute :first_name, :integer
      end

      it 'returns error' do
        expect(diff).to eq([
          "SchemaDiff::EmployeeResource: attribute :first_name changed type from \"string\" to \"integer\".",
          "SchemaDiff::EmployeeResource: filter :first_name changed type from \"string\" to \"integer\"."
        ])
      end
    end

    context 'when attribute changes readable' do
      include_examples 'changing attribute flag', :readable
    end

    context 'when attribute changes writable' do
      include_examples 'changing attribute flag', :writable
    end

    context 'when attribute changes sortable' do
      include_examples 'changing attribute flag', :sortable
    end

    context 'when attribute is added' do
      before do
        resource_b.attribute :foo, :string
      end

      it { is_expected.to eq([]) }
    end

    context 'when attribute is removed' do
      before do
        resource_b
        resource_a.attribute :foo, :string
      end

      it 'returns error' do
        expect(diff).to eq([
          "SchemaDiff::EmployeeResource: attribute :foo was removed.",
          "SchemaDiff::EmployeeResource: filter :foo was removed."
        ])
      end
    end

    context 'when resource is added' do
      let(:another) do
        Class.new(application_resource) do
          def self.name;'SchemaDiff::AnotherResource';end
        end
      end

      before do
        b_resources << another
      end

      it 'returns true' do
        expect(diff).to eq([])
        expect(a[:resources].length).to eq(1)
        expect(b[:resources].length).to eq(2)
      end
    end

    context 'when a resource is removed' do
      let(:another) do
        Class.new(application_resource) do
          def self.name;'SchemaDiff::AnotherResource';end
        end
      end

      before do
        resource_b
        a_resources << another
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::AnotherResource was removed.',
          'Endpoint "/schema_diff/anothers" was removed.'
        ])
      end
    end

    context 'when a resource changes type' do
      before do
        resource_a.type = :employees
        resource_b.type = :special_employees
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource changed type from "employees" to "special_employees".'
        ])
      end
    end

    context 'when extra attribute added' do
      before do
        resource_b.extra_attribute :foo, :string
      end

      it { is_expected.to eq([]) }
    end

    context 'when extra attribute removed' do
      before do
        resource_b
        resource_a.extra_attribute :foo, :string
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: extra attribute :foo was removed.'
        ])
      end
    end

    context 'when extra attribute changes type' do
      before do
        resource_a.extra_attribute :foo, :string
        resource_b.extra_attribute :foo, :integer
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: extra attribute :foo changed type from "string" to "integer".'
        ])
      end
    end

    context 'when extra attribute goes readable :guarded to true' do
      before do
        resource_a.extra_attribute :foo, :string, readable: :admin?
        resource_b.extra_attribute :foo, :string, readable: true
      end

      it { is_expected.to eq([]) }
    end

    context 'when extra attribute goes readable true to :guarded' do
      before do
        resource_a.extra_attribute :foo, :string, readable: true
        resource_b.extra_attribute :foo, :string, readable: :admin?
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: extra attribute :foo changed flag :readable from true to "guarded".'
        ])
      end
    end

    context 'when extra attribute goes readable false to :guarded' do
      before do
        resource_a.extra_attribute :foo, :string, readable: false
        resource_b.extra_attribute :foo, :string, readable: :admin?
      end

      it { is_expected.to eq([]) }
    end

    context 'when extra attribute goes readable :guarded to false' do
      before do
        resource_a.extra_attribute :foo, :string, readable: :admin?
        resource_b.extra_attribute :foo, :string, readable: false
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: extra attribute :foo changed flag :readable from "guarded" to false.'
        ])
      end
    end

    context 'when filter is added' do
      before do
        resource_b.filter :foo, :string
      end

      it { is_expected.to eq([]) }
    end

    context 'when filter is removed' do
      before do
        resource_b
        resource_a.filter :foo, :string
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: filter :foo was removed.'
        ])
      end
    end

    context 'when filter changes type' do
      before do
        resource_b.filter :foo, :integer
        resource_a.filter :foo, :string
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: filter :foo changed type from "string" to "integer".'
        ])
      end
    end

    context 'when filter adds operator' do
      before do
        resource_b.filter :foo, :string do
          bar do
          end
        end
        resource_a.filter :foo, :string
      end

      it { is_expected.to eq([]) }
    end

    context 'when filter removes operator' do
      before do
        resource_b.filter :foo, :string
        resource_a.filter :foo, :string do
          bar do
          end
        end
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: filter :foo removed operator "bar".'
        ])
      end
    end

    context 'when filter goes :required to not' do
      before do
        resource_b.filter :foo, :string
        resource_a.filter :foo, :string, required: true
      end

      it { is_expected.to eq([]) }
    end

    context 'when filter becomes required' do
      before do
        resource_b.attribute :foo, :string, filterable: :required
        resource_a.attribute :foo, :string
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: filter :foo went from optional to required.'
        ])
      end
    end

    context 'when filter goes unguarded to guarded' do
      before do
        resource_b.attribute :foo, :string, filterable: :admin?
        resource_a.attribute :foo, :string
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: filter :foo went from unguarded to guarded.'
        ])
      end
    end

    context 'when filter goes guarded to unguarded' do
      before do
        resource_b.attribute :foo, :string
        resource_a.attribute :foo, :string, filterable: :admin?
      end

      it { is_expected.to eq([]) }
    end

    context 'when relationship is added' do


      before do
        resource_b.has_many :positions, resource: position_resource
      end

      it { is_expected.to eq([]) }
    end

    context 'when relationship is removed' do
      before do
        resource_b
        resource_a.has_many :positions, resource: position_resource
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: relationship :positions was removed.'
        ])
      end
    end

    context 'when relationship changes resource' do
      let(:position_resource2) do
        Class.new(application_resource) do
          def self.name;'SchemaDiff::PositionResource2';end
        end
      end

      before do
        resource_b.has_many :positions, resource: position_resource2
        resource_a.has_many :positions, resource: position_resource
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: relationship :positions changed resource from SchemaDiff::PositionResource to SchemaDiff::PositionResource2.'
        ])
      end
    end

    context 'when relationship changes type' do
      before do
        resource_b.belongs_to :positions, resource: position_resource
        resource_a.has_many :positions, resource: position_resource
      end

      it 'returns error' do
        expect(diff).to eq([
          'SchemaDiff::EmployeeResource: relationship :positions changed type from "has_many" to "belongs_to".'
        ])
      end
    end

    context 'when type is added' do
      around do |e|
        JsonapiCompliable::Types[:foo] = {
          read: '',
          write: '',
          params: '',
          kind: '',
          description: ''
        }
        begin
          e.run
        ensure
          JsonapiCompliable::Types.map.delete(:foo)
        end
      end

      it { is_expected.to eq([]) }
    end

    context 'when type is removed' do
      before do
        JsonapiCompliable::Types[:foo] = {
          read: '',
          write: '',
          params: '',
          kind: '',
          description: ''
        }
        a
        JsonapiCompliable::Types.map.delete(:foo)
      end

      it 'returns error' do
        expect(diff).to eq([
          'Type :foo was removed.'
        ])
      end
    end

    context 'when type changes kind' do
      before do
        JsonapiCompliable::Types[:foo] = {
          read: '',
          write: '',
          params: '',
          kind: 'scalar',
          description: ''
        }
        a
        JsonapiCompliable::Types[:foo] = {
          read: '',
          write: '',
          params: '',
          kind: 'array',
          description: ''
        }
        b
        JsonapiCompliable::Types.map.delete(:foo)
      end

      it 'returns error' do
        expect(diff).to eq([
          'Type :foo changed kind from "scalar" to "array".'
        ])
      end
    end

    context 'when endpoint is added' do
      before do
        b_resources << position_resource
      end

      it 'returns true' do
        expect(diff).to eq([])
        expect(b[:endpoints].length).to eq(2)
      end
    end

    context 'when endpoint is removed' do
      let(:position_resource_no_endpoint) do
        Class.new(JsonapiCompliable::Resource) do
          def self.name;'SchemaDiff::PositionResource';end
          self.endpoint = nil
        end
      end

      before do
        b_resources << position_resource_no_endpoint
        a_resources << position_resource
      end

      it 'returns true' do
        expect(diff).to eq([
          'Endpoint "/schema_diff/positions" was removed.'
        ])
      end
    end

    context 'when endpoint action is removed' do
      let(:position_resource_no_create) do
        Class.new(JsonapiCompliable::Resource) do
          def self.name;'SchemaDiff::PositionResource';end
          self.endpoint[:actions].delete(:create)
        end
      end

      before do
        b_resources << position_resource_no_create
        a_resources << position_resource
      end

      it 'returns error' do
        expect(diff).to eq([
          'Endpoint "/schema_diff/positions" removed action :create.'
        ])
      end
    end

    context 'when an endpoint action sideload whitelist is added' do
      before do
        a
        test_context.sideload_whitelist = { index: [:positions] }
      end

      it 'returns error' do
        expect(diff).to eq([
          'Endpoint "/schema_diff/employees" added sideload whitelist.'
        ])
      end
    end

    context 'when an endpoint action sideload whitelist is removed' do
      before do
        test_context.sideload_whitelist = { index: [:positions] }
        a
        test_context.sideload_whitelist = nil
      end

      it 'returns true' do
        expect(a[:endpoints].values[0][:actions][:index][:sideload_whitelist])
          .to eq([:positions])
        expect(diff).to eq([])
      end
    end

    context 'when an endpoint action sideload whitelist changes' do
      context 'with an addition' do
        before do
          test_context.sideload_whitelist = {
            index: [:positions]
          }
          a
          test_context.sideload_whitelist = { index: { positions: :department } }
        end

        it { is_expected.to eq([]) }
      end

      context 'with a removal' do
        before do
          test_context.sideload_whitelist = {
            index: [
              { positions: :department },
              :same
            ]
          }
          a
          test_context.sideload_whitelist = { index: [:positions, :same] }
        end

        it 'returns error' do
          expect(diff).to eq([
            'Endpoint "/schema_diff/employees" had incompatible sideload whitelist. Was [{:positions=>:department}, :same], now [:positions, :same].'
          ])
        end
      end
    end

    context 'when an endpoint action write attribute whitelist changes' do
      xit 'todo' do
      end
    end

    xit 'when relationship goes from unreadable to readable' do
    end

    xit 'when relationship goes from readable to unreadable' do
    end

    xit 'when relationship goes from unwritable to writable' do
    end

    xit 'when relationship goes from writable to unwritable' do
    end
  end
end
