require 'spec_helper'

RSpec.describe JsonapiCompliable::DSL do
  let(:instance) { described_class.new }

  describe '#copy' do
    let(:copy) { instance.copy }

    it 'returns a new instance' do
      expect(copy).to be_a(described_class)
      expect(copy.object_id).to_not eq(instance.object_id)
    end

    it 'copies sideloads' do
      instance.sideloads = { foo: 'bar' }
      expect(copy.sideloads).to eq(foo: 'bar')
      expect(copy.sideloads.object_id).to_not eq(instance.sideloads.object_id)
    end

    it 'copies filters' do
      instance.filters = { foo: 'bar' }
      expect(copy.filters).to eq(foo: 'bar')
      expect(copy.filters.object_id).to_not eq(instance.filters.object_id)
    end

    it 'copies default filters' do
      instance.default_filters = { foo: 'bar' }
      expect(copy.default_filters).to eq(foo: 'bar')
      expect(copy.default_filters.object_id).to_not eq(instance.default_filters.object_id)
    end

    it 'copies extra fields' do
      instance.extra_fields = { foo: 'bar' }
      expect(copy.extra_fields).to eq(foo: 'bar')
      expect(copy.extra_fields.object_id).to_not eq(instance.extra_fields.object_id)
    end

    it 'copies sorting' do
      instance.sorting = 'a'
      expect(copy.sorting).to eq(instance.sorting)
      expect(copy.sorting.object_id).to_not eq(instance.sorting.object_id)
    end

    it 'copies pagination' do
      instance.pagination = 'a'
      expect(copy.pagination).to eq(instance.pagination)
      expect(copy.pagination.object_id).to_not eq(instance.pagination.object_id)
    end

    it 'copies stats' do
      instance.stats = { foo: 'bar' }
      expect(copy.stats).to eq(foo: 'bar')
      expect(copy.stats.object_id).to_not eq(instance.stats.object_id)
    end
  end

  describe '#clear' do
    before do
      instance.sideloads = { foo: 'bar' }
      instance.filters = { foo: 'bar' }
      instance.default_filters = { foo: 'bar' }
      instance.extra_fields = { foo: 'bar' }
      instance.stats = { foo: 'bar' }
      instance.sorting = 'a'
      instance.pagination = 'a'
    end

    it 'resets sideloads' do
      expect {
        instance.clear!
      }.to change { instance.sideloads }.to({})
    end

    it 'resets filters' do
      expect {
        instance.clear!
      }.to change { instance.filters }.to({})
    end

    it 'resets default filters' do
      expect {
        instance.clear!
      }.to change { instance.default_filters }.to({})
    end

    it 'resets extra fields' do
      expect {
        instance.clear!
      }.to change { instance.extra_fields }.to({})
    end

    it 'resets sorting' do
      expect {
        instance.clear!
      }.to change { instance.sorting }.to(nil)
    end

    it 'resets pagination' do
      expect {
        instance.clear!
      }.to change { instance.pagination }.to(nil)
    end

    it 'resets stats' do
      expect {
        instance.clear!
      }.to change { instance.stats }.to({})
    end
  end

  describe '#stat' do
    let(:avg_proc) { proc { |scope, attr| 1 } }

    before do
      dsl = JsonapiCompliable::Stats::DSL.new(:myattr)
      dsl.average(&avg_proc)
      instance.stats = { myattr: dsl }
    end

    context 'when passing strings' do
      it 'returns the corresponding proc' do
        expect(instance.stat('myattr', 'average')).to eq(avg_proc)
      end
    end

    context 'when passing symbols' do
      it 'returns the corresponding proc' do
        expect(instance.stat(:myattr, :average)).to eq(avg_proc)
      end
    end

    context 'when no corresponding attribute' do
      it 'raises error' do
        expect { instance.stat(:foo, 'average') }
          .to raise_error(JsonapiCompliable::Errors::StatNotFound, "No stat configured for calculation 'average' on attribute :foo")
      end
    end

    context 'when no corresponding calculation' do
      it 'raises error' do
        expect { instance.stat('myattr', :median) }
          .to raise_error(JsonapiCompliable::Errors::StatNotFound, "No stat configured for calculation :median on attribute :myattr")
      end
    end
  end

  describe '#with_context' do
    it 'sets/resets correct context' do
      dbl = double
      instance.with_context(dbl, :index) do
        expect(instance.context).to eq(object: dbl, namespace: :index)
      end
      expect(instance.context).to eq({})
    end

    context 'when an error' do
      it 'resets the context' do
        expect {
          instance.with_context({}, :index) do
            raise 'foo'
          end
        }.to raise_error('foo')
        expect(instance.context).to eq({})
      end
    end
  end

  describe '#default_sort' do
    it 'gets/sets correctly' do
      instance.default_sort([{ name: :desc }])
      expect(instance.default_sort).to eq([{ name: :desc }])
    end

    it 'defaults' do
      expect(instance.default_sort).to eq([{ id: :asc }])
    end
  end

  describe '#default_page_number' do
    it 'gets/sets correctly' do
      instance.default_page_number(2)
      expect(instance.default_page_number).to eq(2)
    end

    it 'defaults' do
      expect(instance.default_page_number).to eq(1)
    end
  end

  describe '#default_page_size' do
    it 'gets/sets correctly' do
      instance.default_page_size(10)
      expect(instance.default_page_size).to eq(10)
    end

    it 'defaults' do
      expect(instance.default_page_size).to eq(20)
    end
  end

  describe '#type' do
    it 'gets/sets correctly' do
      instance.type :authors
      expect(instance.type).to eq(:authors)
    end

    it 'defaults' do
      expect(instance.type).to eq(:undefined_jsonapi_type)
    end
  end

  describe '#association_names' do
    it 'collects all keys in all whitelists, without dupes' do
      instance.includes whitelist: { index: [{ books: :genre }, :state], show: [:state, :bio] }
      expect(instance.association_names).to eq([:books, :genre, :state, :bio])
    end

    context 'when no whitelist' do
      it 'defaults to empty array' do
        expect(instance.association_names).to eq([])
      end
    end
  end

  describe '#allowed_sideloads' do
    subject { instance.allowed_sideloads }

    context 'when no whitelist' do
      it { is_expected.to eq({}) }
    end

    context 'when a whitelist' do
      before do
        instance.includes whitelist: {
          index: [{ foo: :bar }, :baz],
          show: :blah
        }
      end

      context 'and a namespace is set' do
        around do |e|
          instance.with_context({}, :show) do
            e.run
          end
        end

        it { is_expected.to eq({ blah: {} }) }
      end

      context 'and a namespace is not set' do
        it { is_expected.to eq({ foo: { bar: {} }, baz: {}, blah: {} }) }
      end
    end
  end
end
