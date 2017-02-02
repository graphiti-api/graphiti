require 'spec_helper'

RSpec.describe JsonapiCompliable::Sideload do
  let(:opts)     { {} }
  let(:instance) { described_class.new(:foo, opts) }

  describe '.new' do
    it 'assigns an instance of a subclass of resource' do
      expect(instance.resource).to be_a(JsonapiCompliable::Resource)
      expect(instance.resource.class.object_id).to_not eq(JsonapiCompliable::Resource)
    end

    it "extends the resource with the adapter's sideloading module" do
      mod = Module.new do
        def foo
          'bar'
        end
      end
      adapter = JsonapiCompliable::Adapters::Abstract.new
      allow(adapter).to receive(:sideloading_module) { mod }
      allow_any_instance_of(JsonapiCompliable::Resource).to receive(:adapter) { adapter }
      expect(instance.foo).to eq('bar')
    end

    context 'when passed :resource' do
      let(:resource_instance) { JsonapiCompliable::Resource.new }

      before do
        resource = double(new: resource_instance)
        opts[:resource] = resource
      end

      it 'assigns an instance of that resource' do
        expect(instance.resource).to eq(resource_instance)
      end
    end
  end

  describe '#allow_sideload' do
    it 'assigns a new sideload' do
      instance.allow_sideload :bar
      expect(instance.sideloads[:bar]).to be_a(JsonapiCompliable::Sideload)
    end

    it 'evaluates the given block in the context of the new sideload' do
      instance.allow_sideload :bar do
        instance_variable_set(:@foo, 'foo')
      end
      expect(instance.sideloads[:bar].instance_variable_get(:@foo))
        .to eq('foo')
    end

    context 'when polymorphic' do
      before do
        opts[:polymorphic] = true
      end

      it 'adds a new sideload to polymorphic groups' do
        instance.allow_sideload :bar
        groups = instance.instance_variable_get(:@polymorphic_groups)
        expect(groups[:bar]).to be_a(JsonapiCompliable::Sideload)
      end

      it 'does not add to sideloads' do
        instance.allow_sideload :bar
        expect(instance.sideloads).to be_empty
      end
    end
  end

  describe '#to_hash' do
    before do
      instance.allow_sideload :bar do
        allow_sideload :baz do
          allow_sideload :bazoo
        end
      end
      instance.allow_sideload :blah
    end

    it 'recursively builds a hash of sideloads' do
      expect(instance.to_hash).to eq({
        foo: {
          bar: {
            baz: {
              bazoo: {}
            }
          },
          blah: {}
        }
      })
    end
  end
end
