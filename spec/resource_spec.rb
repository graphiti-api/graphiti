require 'spec_helper'

RSpec.describe JsonapiCompliable::Resource do
  let(:klass) { Class.new(described_class) }
  let(:instance) { klass.new }

  # This is the test for all 'config' behavior
  context 'when inheriting' do
    before do
      klass.class_eval do
        allow_sideload :foo
      end
    end

    let(:subclass) do
      Class.new(klass)
    end

    it 'inherits sideloads'  do
      expect(subclass.config[:sideloads].keys).to eq([:foo])
    end

    it 'does not modify superclass sideloads' do
      subclass.class_eval do
        allow_sideload :bar
      end
      expect(subclass.config[:sideloads].keys).to eq([:foo, :bar])
      expect(klass.config[:sideloads].keys).to eq([:foo])
    end
  end

  describe '#stat' do
    let(:avg_proc) { proc { |scope, attr| 1 } }

    before do
      klass.class_eval do
        allow_stat :myattr do
          average { |scope, attr| 1 }
        end
      end
    end

    context 'when passing strings' do
      it 'returns the corresponding proc' do
        expect(instance.stat('myattr', 'average').call(nil, nil)).to eq(1)
      end
    end

    context 'when passing symbols' do
      it 'returns the corresponding proc' do
        expect(instance.stat(:myattr, :average).call(nil, nil)).to eq(1)
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
        expect(instance.context).to eq(dbl)
        expect(instance.context_namespace).to eq(:index)
      end
      expect(instance.context).to be_nil
      expect(instance.context_namespace).to be_nil
    end

    context 'when an error' do
      around do |e|
        JsonapiCompliable.with_context('orig', 'orig namespace') do
          e.run
        end
      end

      it 'resets the context' do
        expect {
          instance.with_context({}, :index) do
            raise 'foo'
          end
        }.to raise_error('foo')
        expect(instance.context).to eq('orig')
        expect(instance.context_namespace).to eq('orig namespace')
      end
    end
  end

  describe '#default_sort' do
    it 'defaults' do
      expect(instance.default_sort).to eq([])
    end
  end

  describe '#default_page_size' do
    it 'defaults' do
      expect(instance.default_page_size).to eq(20)
    end
  end

  describe '#type' do
    it 'defaults' do
      expect(instance.type).to eq(:undefined_jsonapi_type)
    end
  end

  describe '#adapter' do
    it 'defaults' do
      expect(instance.adapter.class).to eq(JsonapiCompliable::Adapters::Abstract)
    end
  end

  describe '.allow_sideload' do
    it 'uses Sideload as default class' do
      sideload = klass.allow_sideload :comments
      expect(sideload.class.ancestors[1]).to eq(JsonapiCompliable::Sideload)
    end

    it 'assigns parent resource as self' do
      sideload = klass.allow_sideload :comments
      expect(sideload.parent_resource_class).to eq(klass)
    end

    it 'adds to the list of sideloads' do
      sideload = klass.allow_sideload :comments
      expect(klass.sideloads[:comments]).to eq(sideload)
    end

    it 'passes options to the sideload constructor' do
      sideload = klass.allow_sideload :comments, type: :foo
      expect(sideload.type).to eq(:foo)
    end

    context 'when passed a block' do
      it 'is processed' do
        sideload = klass.allow_sideload :comments do
          scope do |parents|
            'foo'
          end
        end
        expect(sideload.class.scope_proc.call([])).to eq('foo')
      end
    end

    context 'when passed explicit :class' do
      it 'is used' do
        sideload = klass.allow_sideload :comments,
          class: JsonapiCompliable::Sideload::HasMany
        expect(sideload.class.ancestors[1])
          .to eq(JsonapiCompliable::Sideload::HasMany)
      end
    end
  end

  describe '.association_names' do
    it 'collects nested + resource sideloads' do
      position_resource = Class.new(PORO::PositionResource) do
        belongs_to :department
        def self.name
          'PORO::PositionResource'
        end
      end
      klass.has_many :positions, resource: position_resource
      expect(klass.association_names)
        .to match_array([:positions, :department])
    end

    context 'when no whitelist' do
      it 'defaults to empty array' do
        expect(klass.association_names).to eq([])
      end
    end
  end

  describe '#resolve' do
    it 'delegates to the adapter' do
      scope = double
      expect(instance.adapter).to receive(:resolve).with(scope)
      instance.resolve(scope)
    end
  end
end
