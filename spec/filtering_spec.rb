require 'spec_helper'

RSpec.describe 'filtering' do
  include_context 'resource testing'
  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name;'PORO::EmployeeResource';end
    end
  end
  let(:base_scope) { { type: :employees, conditions: {} } }

  let!(:employee1) do
    PORO::Employee.create(first_name: 'Stephen', last_name: 'King')
  end
  let!(:employee2) do
    PORO::Employee.create(first_name: 'Agatha', last_name: 'Christie')
  end
  let!(:employee3) do
    PORO::Employee.create(first_name: 'William', last_name: 'Shakesphere')
  end
  let!(:employee4) do
    PORO::Employee.create(first_name: 'Harold',  last_name: 'Robbins')
  end

  it 'scopes correctly' do
    params[:filter] = { id: { eq: employee1.id } }
    expect(records.map(&:id)).to eq([employee1.id])
  end

  context 'when filter is type hash' do
    before do
      resource.filter :by_json, :hash do
        eq do |scope, value|
          ids = value.map { |v| [v['id'], v['id2']] }.flatten
          scope[:conditions].merge!(id: ids)
          scope
        end
      end
      params[:filter] = { by_json: '{ "id": 2 }' }
    end

    it 'works' do
      expect(records.map(&:id)).to eq([employee2.id])
    end

    context 'and the hash has multiple keys' do
      before do
        params[:filter] = { by_json: '{ "id": 2, "id2": 3 }' }
      end

      it 'still works' do
        expect(records.map(&:id)).to eq([employee2.id, employee3.id])
      end
    end

    context 'and an array of json objects passed' do
      before do
        params[:filter] = {
          by_json: '{ "id": 2, "id2": 3 },{ "id": 4 },{ "id": 5 },{ "id": 6 }'
        }
      end

      it 'works' do
        expect(records.map(&:id))
          .to eq([employee2.id, employee3.id, employee4.id])
      end
    end
  end

  context 'when filter is a {{string}} with a comma' do
    before do
      params[:filter] = { first_name: '{{foo,bar}}' }
      employee2.update_attributes(first_name: 'foo,bar')
    end

    it 'does not convert to array' do
      expect(records.map(&:id)).to eq([employee2.id])
    end

    context 'when an array of escaped/non-escaped strings' do
      before do
        params[:filter] = { first_name: '{{foo,bar}},Stephen,{{Harold}}' }
      end

      it 'works correctly' do
        expect(records.map(&:id)).to eq([
          employee1.id,
          employee2.id,
          employee4.id
        ])
      end
    end

    context 'when an escaped string contains quoted strings' do
      before do
        params[:filter] = { first_name: '{{foo "bar"}},baz' }
        employee2.update_attributes(first_name: 'foo "bar"')
        employee3.update_attributes(first_name: 'baz')
      end

      it 'works correctly' do
        expect(records.map(&:id)).to eq([employee2.id, employee3.id])
      end
    end
  end

  context 'when filter is a {{string}} without a comma' do
    before do
      params[:filter] = { first_name: '{{foo}}' }
      employee2.update_attributes(first_name: 'foo')
    end

    it 'does not convert to array' do
      expect(records.map(&:id)).to eq([employee2.id])
    end

    context 'when an escaped string contains quoted strings' do
      before do
        params[:filter] = { first_name: '{{"foo"}}' }
        employee2.update_attributes(first_name: '"foo"')
      end

      it 'works correctly' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end
  end

  # Legacy Compat
  context 'when filter value is {{{escaped json string}}}' do
    before do
      params[:filter] = { by_json: '{{{ "id": 2 }}}' }
    end

    context 'and type is hash' do
      before do
        resource.filter :by_json, :hash do
          eq do |scope, value|
            scope[:conditions].merge!(id: value[0]['id'])
            scope
          end
        end
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end
  end

  context 'when filter overrides attribute type' do
    before do
      resource.attribute :foo, :string
      resource.filter :foo, :integer
    end

    it 'does not change attribute type' do
      expect(resource.attributes[:foo][:type]).to eq(:string)
    end

    it 'does change type on filter' do
      expect(resource.filters[:foo][:type]).to eq(:integer)
    end

    it 'queries correctly' do
      expect(PORO::DB).to receive(:all).with(
        hash_including(conditions: { foo: [1] })
      ).and_return([])
      params[:filter] = { foo: '1' }
      records
    end
  end

  context 'when filtering associations' do
    context 'one level' do
      let!(:pos1) do
        PORO::Position.create title: 'foo',
          employee_id: employee1.id
      end
      let!(:pos2) do
        PORO::Position.create title: 'bar',
          employee_id: employee1.id
      end

      before do
        params[:filter] = {
          id: employee1.id,
          :'positions.title' => 'bar'
        }
        params[:include] = 'positions'
      end

      it 'works' do
        render
        sl = d[0].sideload(:positions)
        expect(sl.map(&:id)).to eq([pos2.id])
      end
    end

    context 'multiple levels' do
      let!(:department1) { PORO::Department.create(name: 'foo') }
      let!(:department2) { PORO::Department.create(name: 'bar') }
      let!(:pos1) do
        PORO::Position.create department_id: department1.id,
          employee_id: employee1.id
      end
      let!(:pos2) do
        PORO::Position.create department_id: department2.id,
          employee_id: employee1.id
      end

      before do
        params[:filter] = {
          id: employee1.id,
          :'positions.department.name' => 'bar'
        }
        params[:include] = 'positions.department'
      end

      it 'works' do
        render
        positions = d[0].sideload(:positions)
        expect(positions[0].sideload(:department)).to be_nil
        expect(positions[1].sideload(:department).id).to eq(department2.id)
      end

      context 'with customized sort params' do
        before do
          resource.has_many :positions do
            params do |hash|
              hash[:sort] = '-id'
            end
          end
        end

        it 'works' do
          render
          positions = d[0].sideload(:positions)
          expect(positions[0].sideload(:department).id).to eq(department2.id)
          expect(positions[1].sideload(:department)).to be_nil
        end
      end

      context 'with customized filter params' do
        before do
          resource.has_many :positions do
            params do |hash|
              hash[:filter][:id] = 2
            end
          end
        end

        it 'works' do
          render
          positions = d[0].sideload(:positions)
          expect(positions.map(&:id)).to eq([2])
          expect(positions[0].sideload(:department).id).to eq(department2.id)
        end
      end
    end
  end

  context 'when only allowing single values' do
    before do
      resource.filter :first_name, :string, single: true do
        eq do |scope, value|
          scope[:conditions].merge!(first_name: value)
          scope
        end
      end
    end

    it 'rejects multiples' do
      params[:filter] = { first_name: { eq: 'William,Harold' } }
      expect {
        records
      }.to raise_error(Graphiti::Errors::SingularFilter, /passed multiple values to filter :first_name/)
    end

    it 'allows singles' do
      params[:filter] = { first_name: { eq: 'William' } }
      expect(records.map(&:id)).to eq([employee3.id])
    end

    it 'yields a singular value' do
      expect(PORO::DB).to receive(:all)
        .with(hash_including(conditions: { first_name: 'William' }))
        .and_call_original
      params[:filter] = { first_name: { eq: 'William' } }
      expect(records.map(&:id)).to eq([employee3.id])
    end

    context 'and allowlisting inputs' do
      before do
        resource.config[:filters] = {}
        resource.filter :first_name, :string, single: true, allow: ['William'] do
          eq do |scope, value|
            scope[:conditions].merge!(first_name: value)
            scope
          end
        end
      end

      it 'rejects values not in the allowlist' do
        params[:filter] = { first_name: { eq: 'Harold' } }
        expect {
          records
        }.to raise_error( Graphiti::Errors::InvalidFilterValue, /Allowlist: \[\"William\"\]/)
      end

      it 'accepts values in the allowlist' do
        params[:filter] = { first_name: { eq: 'William' } }
        expect(records.map(&:id)).to eq([employee3.id])
      end
    end

    context 'and denylisting inputs' do
      before do
        resource.config[:filters] = {}
        resource.filter :first_name, :string, single: true, deny: ['Harold'] do
          eq do |scope, value|
            scope[:conditions].merge!(first_name: value)
            scope
          end
        end
      end

      it 'rejects values in the denylist' do
        params[:filter] = { first_name: { eq: 'Harold' } }
        expect {
          records
        }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Denylist: \[\"Harold\"\]/)
      end

      it 'accepts values not in the denylist' do
        params[:filter] = { first_name: { eq: 'William' } }
        expect(records.map(&:id)).to eq([employee3.id])
      end
    end
  end

  context 'when allowlisting inputs' do
    before do
      resource.config[:filters] = {}
      resource.filter :first_name, :string, allow: ['William', 'Agatha'] do
        eq do |scope, value|
          scope[:conditions].merge!(first_name: value)
          scope
        end
      end
    end

    it 'rejects values not in the allowlist' do
      params[:filter] = { first_name: { eq: 'Harold' } }
      expect {
        records
      }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Allowlist: \["William", "Agatha"\]/)
    end

    it 'accepts values in the allowlist' do
      params[:filter] = { first_name: { eq: 'William' } }
      expect(records.map(&:id)).to eq([employee3.id])
    end

    context 'and passed an array' do
      context 'where one value is not allowlisted' do
        before do
          params[:filter] = { first_name: { eq: ['Harold', 'William'] } }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Allowlist: \["William", "Agatha"\]/)
        end
      end

      context 'where all values are in allowlist' do
        before do
          params[:filter] = { first_name: { eq: ['Agatha', 'William'] } }
        end

        it 'works' do
          expect(records.map(&:id)).to eq([employee2.id, employee3.id])
        end
      end
    end
  end

  context 'when denylisting inputs' do
    before do
      resource.config[:filters] = {}
      resource.filter :first_name, :string, deny: ['Harold'] do
        eq do |scope, value|
          scope[:conditions].merge!(first_name: value)
          scope
        end
      end
    end

    it 'rejects values in the denylist' do
      params[:filter] = { first_name: { eq: 'Harold' } }
      expect {
        records
      }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Denylist: \[\"Harold\"\]/)
    end

    it 'accepts values not in the denylist' do
      params[:filter] = { first_name: { eq: 'William' } }
      expect(records.map(&:id)).to eq([employee3.id])
    end

    context 'and passed an array' do
      context 'where one value is in the denylist' do
        before do
          params[:filter] = { first_name: { eq: ['Harold', 'William'] } }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::InvalidFilterValue, /Denylist: \["Harold"\]/)
        end
      end

      context 'where no values are in the denylist' do
        before do
          params[:filter] = { first_name: { eq: ['Agatha', 'William'] } }
        end

        it 'works' do
          expect(records.map(&:id)).to eq([employee2.id, employee3.id])
        end
      end
    end
  end

  context 'when attribute already defined' do
    before do
      resource.attribute :foo, :string
    end

    context 'and single: true passed' do
      before do
        resource.filter :foo, single: true
      end

      it 'is applied' do
        expect(resource.filters[:foo][:single]).to eq(true)
      end
    end
  end

  context 'when dependent filter' do
    before do
      resource.filter :baz, :string
      resource.filter :bar, :string, dependent: [:foo]
      resource.filter :foo, :string, dependent: [:bar, :baz]
    end

    context 'when dependencies also passed' do
      before do
        params[:filter] = {
          foo: 'a',
          bar: 'b',
          baz: 'c'
        }
      end

      it 'works' do
        expect {
          records
        }.to_not raise_error
      end
    end

    context 'when dependencies not passed' do
      before do
        params[:filter] = { foo: 'a' }
      end

      it 'raises error' do
        expect {
          records
        }.to raise_error(Graphiti::Errors::MissingDependentFilter)
      end
    end

    context 'when querying on something unrelated' do
      before do
        resource.filter :another, :string do
          eq { |scope| scope }
        end
      end

      it 'does not raise error' do
        expect {
          records
        }.to_not raise_error
      end
    end
  end

  context 'when boolean filter' do
    before do
      resource.filter :active, :boolean
    end

    it 'is single by default' do
      expect(resource.filters[:active][:single]).to eq(true)
    end
  end

  # NB: even though query params are always strings, I'd like to
  # support vanilla query interface coercions as well.
  # Which is why you see tests for it.
  describe 'types' do
    def assert_filter_value(value)
      expect(PORO::DB).to receive(:all)
        .with(hash_including(conditions: { foo: value }))
        .and_return([])
      records
    end

    context 'when integer_id' do
      before do
        resource.attribute :foo, :integer_id
      end

      it 'queries via integer' do
        params[:filter] = { foo: '1' }
        assert_filter_value([1])
      end
    end

    context 'when string' do
      before do
        resource.attribute :foo, :string
      end

      it 'coerces' do
        params[:filter] = { foo: 1 }
        assert_filter_value(['1'])
      end

      context 'and passed json array' do
        context 'with non-strings' do
          before do
            params[:filter] = { foo: '[1,2,3]' }
          end

          it 'coerces to strings' do
            assert_filter_value(['1', '2', '3'])
          end
        end

        context 'with valid json' do
          before do
            params[:filter] = { foo: '["1","2","3"]' }
          end

          it 'works' do
            assert_filter_value(['1', '2', '3'])
          end
        end

        context 'with invalid json' do
          before do
            params[:filter] = { foo: '[foo]' }
          end

          it 'works' do
            expect {
              records
            }.to raise_error(Graphiti::Errors::InvalidJSONArray)
          end
        end
      end
    end

    context 'when integer' do
      before do
        resource.attribute :foo, :integer
      end

      it 'coerces' do
        params[:filter] = { foo: '1' }
        assert_filter_value([1])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when decimal' do
      before do
        resource.attribute :foo, :big_decimal
      end

      it 'coerces integers' do
        params[:filter] = { foo: 40 }
        assert_filter_value([BigDecimal(40)])
      end

      it 'coerces strings' do
        params[:filter] = { foo: '40.01' }
        assert_filter_value([BigDecimal('40.01')])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        # NB ArgumentError not TypeError
        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when float' do
      before do
        resource.attribute :foo, :float
      end

      it 'coerces strings' do
        params[:filter] = { foo: '40.01' }
        assert_filter_value([40.01])
      end

      it 'coerces integers' do
        params[:filter] = { foo: '40' }
        assert_filter_value([40.0])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        # NB ArgumentError
        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when boolean' do
      before do
        resource.attribute :foo, :boolean
      end

      it 'coerces string true' do
        params[:filter] = { foo: 'true' }
        assert_filter_value(true)
      end

      it 'coerces string false' do
        params[:filter] = { foo: 'false' }
        assert_filter_value(false)
      end

      it 'coerces true integers' do
        params[:filter] = { foo: 1 }
        assert_filter_value(true)
      end

      it 'coerces false integers' do
        params[:filter] = { foo: 0 }
        assert_filter_value(false)
      end

      it 'coerces string true integers' do
        params[:filter] = { foo: '1' }
        assert_filter_value(true)
      end

      it 'coerces string false integers' do
        params[:filter] = { foo: '0' }
        assert_filter_value(false)
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value(nil)
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'asdf' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when date' do
      before do
        resource.attribute :foo, :date
      end

      it 'coerces Date to correct string format' do
        params[:filter] = { foo: '2018/01/06' }
        assert_filter_value([Date.parse('2018-01-06')])
      end

      it 'coerces Time to correct date string format' do
        params[:filter] = { foo: Time.now.iso8601 }
        assert_filter_value([Date.today])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when only month' do
        before do
          params[:filter] = { foo: '2018-01' }
        end

        it 'raises error because that is not a date' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when datetime' do
      before do
        resource.attribute :foo, :datetime
      end

      it 'coerces strings correctly' do
        params[:filter] = { foo: '2018-01-01 4:36pm PST' }
        time = Time.parse('2018-01-01 16:36:00.000000000 -0800')
        assert_filter_value([time])
      end

      it 'coerces iso8601 strings correctly' do
        time = Time.parse('2018-01-06 4:36pm PST')
        params[:filter] = { foo: time.iso8601 }
        assert_filter_value([time])
      end

      it 'coerces Date correctly' do
        params[:filter] = { foo: '2018-01-06' }
        assert_filter_value([DateTime.parse('2018-01-06')])
      end

      it 'allows nils' do
        params[:filter] = { foo: nil }
        assert_filter_value([nil])
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when hash' do
      before do
        resource.attribute :foo, :hash
      end

      it 'works' do
        params[:filter] = { foo: { eq: { bar: 'baz' } } }
        assert_filter_value([{ bar: 'baz' }])
      end

      context 'and passing without eq' do
        it 'works' do
          params[:filter] = { foo: { bar: 'baz' } }
          assert_filter_value([{ bar: 'baz' }])
        end
      end

      context 'when stringified keys' do
        before do
          params[:filter] = {
            'foo' => {
              'eq' => {
                'bar' => {
                  'baz' => 'blah'
                }
              }
            }
          }
        end

        it 'converts to symbolized keys' do
          assert_filter_value([{ bar: { baz: 'blah' } }])
        end
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: { eq: 'bar' } }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when array' do
      before do
        resource.attribute :foo, :array
      end

      it 'works for arrays' do
        params[:filter] = { foo: [1, 2] }
        assert_filter_value([1, 2])
      end

      it 'works for string arrays' do
        params[:filter] = { foo: '1,2' }
        assert_filter_value(['1', '2'])
      end

      it 'works for strings with brackets' do
        params[:filter] = { foo: '[1,2]' }
        assert_filter_value([1, 2])
      end

      it 'works for bracketed strings with quotes' do
        params[:filter] = { foo: '["1","2"]' }
        assert_filter_value(%w(1 2))
      end

      it 'works for array of arrays' do
        params[:filter] = { foo: '[1,2],[3,4]' }
        assert_filter_value([[1, 2], [3, 4]])
      end

      # If we did Array(value), you'd get something incorrect
      # for hashes
      it 'raises error on single values' do
        params[:filter] = { foo: 1 }
        expect {
          records
        }.to raise_error(Graphiti::Errors::TypecastFailed)
      end

      context 'when passed invalid array json' do
        before do
          params[:filter] = { foo: '[|]' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::InvalidJSONArray)
        end
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: 'foo' }
        end

        it 'raises error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    # test for all array_of_*
    context 'when array_of_integers' do
      before do
        resource.attribute :foo, :array_of_integers
      end

      it 'works' do
        params[:filter] = { foo: [1, 2, 3] }
        assert_filter_value([1, 2, 3])
      end

      it 'applies basic coercion of elements' do
        params[:filter] = { foo: ['1', '2', '3'] }
        assert_filter_value([1, 2, 3])
      end

      # If we did Array(value), you'd get something incorrect
      # for hashes
      it 'raises error on single values' do
        params[:filter] = { foo: 1 }
        expect {
          records
        }.to raise_error(Graphiti::Errors::TypecastFailed)
      end

      context 'when cannot coerce' do
        before do
          params[:filter] = { foo: {} }
        end

        it 'raises error' do
          expect {
            render
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context 'when custom type' do
      before do
        type = Dry::Types::Definition
          .new(nil)
          .constructor { |input|
            'custom!'
          }
        Graphiti::Types[:custom] = {
          params: type,
          canonical_name: :string,
          read: type,
          write: type,
          kind: 'scalar',
          description: 'test'
        }
        resource.attribute :foo, :custom
      end

      after do
        Graphiti::Types.map.delete(:custom)
      end

      it 'works' do
        params[:filter] = { foo: '1' }
        assert_filter_value(['custom!'])
      end
    end
  end

  context 'when custom filtering' do
    context 'and the attribute exists' do
      before do
        _2 = employee2.id
        resource.attribute :foo, :string
        resource.filter :foo do
          eq do |scope, value|
            scope[:conditions][:id] = _2
            scope
          end
        end
      end

      it 'is correctly applied' do
        params[:filter] = { foo: 'bar' }
        expect(records.map(&:id)).to eq([employee2.id])
      end

      it 'adds a list of default operators' do
        expect(resource.filters[:foo][:operators].keys).to eq([
          :eq,
          :not_eq,
          :eql,
          :not_eql,
          :prefix,
          :not_prefix,
          :suffix,
          :not_suffix,
          :match,
          :not_match
        ])
        expect(resource.filters[:foo][:operators][:eq]).to be_a(Proc)
        expect(resource.filters[:foo][:operators][:suffix]).to be_nil
      end

      context 'but it is not filterable' do
        before do
          resource.attributes[:foo][:filterable] = false
        end

        it 'raises helpful error' do
          expect {
            resource.filter :foo do
            end
          }.to raise_error(Graphiti::Errors::AttributeError, 'PORO::EmployeeResource: Tried to add filter attribute :foo, but the attribute was marked :filterable => false.')
        end
      end
    end

    context 'and the attribute does not exist' do
      before do
        _2 = employee2.id
        resource.filter :foo, :string do
          eq do |scope, value|
            scope[:conditions][:id] = _2
            scope
          end
        end
        params[:filter] = { foo: 'bar' }
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end

      it 'adds an only: [:filterable] attribute' do
        att = resource.attributes[:foo]
        expect(att[:readable]).to eq(false)
        expect(att[:writable]).to eq(false)
        expect(att[:sortable]).to eq(false)
        expect(att[:filterable]).to eq(true)
        expect(att[:type]).to eq(:string)
      end

      context 'when no type given' do
        before do
          resource.attributes.delete(:foo)
        end

        it 'blows up' do
          expect {
            resource.filter :foo do
            end
          }.to raise_error(Graphiti::Errors::ImplicitFilterTypeMissing)
        end
      end
    end

    context 'and given :only option' do
      context 'and the attribute already exists' do
        before do
          resource.attribute :foo, :string
          resource.filter :foo, only: [:eq] do
            foo do
            end
          end
        end

        it 'limits available operators' do
          expect(resource.filters[:foo][:operators].keys).to eq([:eq, :foo])
        end
      end

      context 'and no attribute already exists' do
        before do
          resource.filter :foo, :string, only: [:eq] do
            foo do
            end
          end
        end

        it 'limits available operators, adding custom ones' do
          expect(resource.filters[:foo][:operators].keys).to eq([:eq, :foo])
        end
      end

      context 'when only argument is not an array' do
        before do
          resource.filter :foo, :string, only: :eq
        end

        it 'limits available operators' do
          expect(resource.filters[:foo][:operators].keys).to eq([:eq])
        end
      end
    end

    context 'and given :except option' do
      context 'and the attribute already exists' do
        before do
          resource.attribute :foo, :integer
          resource.filter :foo, except: [:eq, :not_eq] do
            foo do
            end
          end
        end

        it 'limits available operators' do
          expect(resource.filters[:foo][:operators].keys).to eq([
            :gt, :gte, :lt, :lte, :foo
          ])
        end
      end

      context 'and no attribute already exists' do
        before do
          resource.filter :foo, :integer, except: [:eq, :not_eq] do
            foo do
            end
          end
        end

        it 'limits available operators, adding custom ones' do
          expect(resource.filters[:foo][:operators].keys).to eq([
            :gt, :gte, :lt, :lte, :foo
          ])
        end
      end

      context 'when except argument is not an array' do
        before do
          resource.filter :foo, :integer, except: :eq
        end

        it 'limits available operators' do
          expect(resource.filters[:foo][:operators].keys).to eq([
            :not_eq, :gt, :gte, :lt, :lte
          ])
        end
      end
    end
  end

  context 'when filtering based on calling context' do
    around do |e|
      Graphiti.with_context(OpenStruct.new(runtime_id: employee3.id)) do
        e.run
      end
    end

    before do
      resource.attribute :foo, :boolean
      resource.filter :foo do
        eq do |scope, value, ctx|
          scope[:conditions][:id] = ctx.runtime_id
          scope
        end
      end
      params[:filter] = { foo: true }
    end

    it 'has access to calling context' do
      expect(records.map(&:id)).to eq([employee3.id])
    end
  end

  context 'when running an implicit attribute filter' do
    before do
      resource.attribute :active, :boolean
    end

    it 'works' do
      params[:filter] = { active: 'true' }
      [employee1, employee3, employee4].each do |e|
        e.update_attributes(active: true)
      end
      employee2.update_attributes(active: false)
      expect(records.map(&:id)).to eq([employee1.id, employee3.id, employee4.id])
    end
  end

  context 'when filter is a "string boolean"' do
    before do
      resource.attribute :active, :boolean
      params[:filter] = { active: 'true' }
      [employee1, employee3, employee4].each do |e|
        e.update_attributes(active: true)
      end
      employee2.update_attributes(active: false)
    end

    it 'automatically casts to a real boolean' do
      ids = records.map(&:id)
      expect(ids.length).to eq(3)
      expect(ids).to_not include(employee2.id)
    end
  end

  context 'when filter is an integer' do
    before do
      params[:filter] = { id: employee1.id }
    end

    it 'still works' do
      expect(records.map(&:id)).to eq([employee1.id])
    end
  end

  context 'when customized with alternate param name' do
    before do
      params[:filter] = { name: 'Stephen' }
    end

    xit 'filters based on the correct name' do
      expect(records.map(&:id)).to eq([employee1.id])
    end
  end

  context 'when the supplied value is comma-delimited' do
    before do
      params[:filter] = { id: [employee1.id, employee2.id].join(',') }
    end

    it 'parses into a ruby array' do
      expect(records.map(&:id)).to eq([employee1.id, employee2.id])
    end
  end

  context 'when a default filter' do
    before do
      resource.class_eval do
        default_filter :first_name do |scope|
          scope[:conditions].merge!(first_name: 'William')
          scope
        end
      end
    end

    it 'applies by default' do
      expect(records.map(&:id)).to eq([employee3.id])
    end

    it 'is overrideable' do
      params[:filter] = { first_name: 'Stephen' }
      expect(records.map(&:id)).to eq([employee1.id])
    end

    context 'without an attribute name' do
      before do
        resource.default_filter do |scope|
          scope[:conditions].merge!(first_name: 'Agatha')
          scope
        end
      end

      it 'is allowed' do
        expect(records.map(&:id)).to eq([employee2.id])
        expect(resource.default_filters[:__default]).to be_present
      end
    end

    xit "is overrideable when overriding via an allowed filter's alias" do
      params[:filter] = { name: 'Stephen' }
      expect(records.map(&:id)).to eq([employee1.id])
    end

    context 'when accessing calling context' do
      before do
        resource.class_eval do
          default_filter :first_name do |scope, ctx|
            scope[:conditions].merge!(id: ctx.runtime_id)
            scope
          end
        end
      end

      it 'works' do
        ctx = double(runtime_id: employee3.id).as_null_object
        Graphiti.with_context(ctx, {}) do
          expect(records.map(&:id)).to eq([employee3.id])
        end
      end
    end
  end

  context 'when filtering on an unknown attribute' do
    before do
      params[:filter] = { foo: 'bar' }
    end

    it 'raises helpful error' do
      expect {
        records
      }.to raise_error(Graphiti::Errors::AttributeError, 'PORO::EmployeeResource: Tried to filter on attribute :foo, but could not find an attribute with that name.')
    end

    context 'but there is a corresponding extra attribute' do
      before do
        resource.extra_attribute :foo, :string
      end

      context 'but it is not filterable' do
        it 'raises helpful error' do
          expect {
            records
          }.to raise_error(Graphiti::Errors::AttributeError, 'PORO::EmployeeResource: Tried to filter on attribute :foo, but the attribute was marked :filterable => false.')
        end
      end

      context 'and it is filterable' do
        before do
          resource.extra_attribute :foo, :string, filterable: true
          _3 = employee3.id
          resource.filter :foo do
            eq do |scope, value|
              scope[:conditions] = { id: _3 }
              scope
            end
          end
        end

        it 'works' do
          expect(records.map(&:id)).to eq([employee3.id])
        end
      end
    end
  end

  context 'when filter is guarded via .attribute' do
    before do
      resource.class_eval do
        attribute :first_name, :string, filterable: :admin?

        def admin?
          !!context.admin
        end
      end
      params[:filter] = { first_name: 'Agatha' }
    end

    context 'and the guard passes' do
      around do |e|
        Graphiti.with_context(OpenStruct.new(admin: true)) do
          e.run
        end
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end

    context 'and the guard fails' do
      around do |e|
        Graphiti.with_context(OpenStruct.new(admin: false)) do
          e.run
        end
      end

      it 'raises helpful error' do
        expect {
          records
        }.to raise_error(Graphiti::Errors::AttributeError, 'PORO::EmployeeResource: Tried to filter on attribute :first_name, but the guard :admin? did not pass.')
      end
    end
  end

  context 'when filter is required on .attribute' do
    before do
      resource.attribute :first_name, :string, filterable: :required
    end

    context 'and given in the request' do
      before do
        params[:filter] = { first_name: 'Agatha' }
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end

    context 'but not given in request' do
      it 'raises error' do
        expect {
          records
        }.to raise_error(Graphiti::Errors::RequiredFilter)
      end
    end
  end

  context 'when filter is required on .filter' do
    before do
      resource.config[:filters] = {}
      resource.config[:attributes] = {}
      resource.filter :first_name, :string, required: true
    end

    context 'and given in the request' do
      before do
        params[:filter] = { first_name: 'Agatha' }
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end

    context 'but not given in request' do
      it 'raises error' do
        expect {
          records
        }.to raise_error(Graphiti::Errors::RequiredFilter)
      end
    end
  end

  context 'when > 1 filter required' do
    before do
      resource.attribute :first_name, :string, filterable: :required
      resource.attribute :last_name, :string, filterable: :required
    end

    context 'but not given in request' do
      it 'raises error that lists all unsupplied filters' do
        expect {
          records
        }.to raise_error(/The required filters "first_name, last_name"/)
      end
    end
  end
end
