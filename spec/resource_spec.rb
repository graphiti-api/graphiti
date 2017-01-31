require 'spec_helper'

RSpec.describe JsonapiCompliable::Resource do
  let(:klass) { Class.new(described_class) }
  let(:instance) { klass.new }

  describe '#copy' do
    let(:copy) { instance.copy }

    it 'returns a new instance' do
      expect(copy).to be_a(described_class)
      expect(copy.object_id).to_not eq(instance.object_id)
    end

    it 'copies the config' do
      instance.set_config(foo: 'bar')
      expect(copy.instance_variable_get(:@config)).to eq(foo: 'bar')
      expect(copy.instance_variable_get(:@config).object_id)
        .to_not eq(instance.instance_variable_get(:@config))
    end

    it 'assigns instance variables' do
      instance.set_config(foo: 'bar')
      expect(copy.instance_variable_get(:@foo)).to eq('bar')
    end
  end

  describe '#stat' do
    let(:avg_proc) { proc { |scope, attr| 1 } }

    before do
      adapter = JsonapiCompliable::Adapters::ActiveRecord.new
      dsl = JsonapiCompliable::Stats::DSL.new(adapter, :myattr)
      dsl.average(&avg_proc)
      instance.instance_variable_set(:@stats, { myattr: dsl })
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
      klass.default_sort([{ name: :desc }])
      expect(instance.default_sort).to eq([{ name: :desc }])
    end

    it 'defaults' do
      expect(instance.default_sort).to eq([{ id: :asc }])
    end
  end

  describe '#default_page_number' do
    it 'gets/sets correctly' do
      klass.default_page_number(2)
      expect(instance.default_page_number).to eq(2)
    end

    it 'defaults' do
      expect(instance.default_page_number).to eq(1)
    end
  end

  describe '#default_page_size' do
    it 'gets/sets correctly' do
      klass.default_page_size(10)
      expect(instance.default_page_size).to eq(10)
    end

    it 'defaults' do
      expect(instance.default_page_size).to eq(20)
    end
  end

  describe '#type' do
    it 'gets/sets correctly' do
      klass.type :authors
      expect(instance.type).to eq(:authors)
    end

    it 'defaults' do
      expect(instance.type).to eq(:undefined_jsonapi_type)
    end
  end

  describe '#association_names' do
    it 'collects all keys in all whitelists, without dupes' do
      klass.includes whitelist: { index: [{ books: :genre }, :state], show: [:state, :bio] }
      expect(instance.association_names).to eq([:books, :genre, :state, :bio])
    end

    context 'when no whitelist' do
      it 'defaults to empty array' do
        expect(instance.association_names).to eq([])
      end
    end
  end

  describe '#allowed_sideloads' do
    subject do
      instance.allowed_sideloads
    end

    context 'when no whitelist' do
      before do
        instance.instance_variable_set(:@sideloads, {})
      end

      it { is_expected.to eq({}) }
    end

    context 'when a whitelist' do
      before do
        klass.includes whitelist: {
          index: [{ foo: :bar }, :baz],
          show: :blah
        }
        instance.set_config(klass.config)
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
