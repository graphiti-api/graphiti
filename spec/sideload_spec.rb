require 'spec_helper'

RSpec.describe JsonapiCompliable::Sideload do
  let(:opts)     { {} }
  let(:instance) { described_class.new(:foo, opts) }

  describe '.new' do
    it 'assigns a resource class' do
      expect(instance.resource_class < JsonapiCompliable::Resource).to eq(true)
      expect(instance.resource_class.object_id).to_not eq(JsonapiCompliable::Resource)
    end

    it "extends the resource with the adapter's sideloading module" do
      mod = Module.new do
        def foo
          'bar'
        end
      end

      adapter = JsonapiCompliable::Adapters::Abstract.new
      allow(adapter).to receive(:sideloading_module) { mod }

      resource = Class.new(JsonapiCompliable::Resource)
      opts[:resource] = resource
      allow(resource).to receive(:config) { { adapter: adapter } }

      expect(instance.foo).to eq('bar')
    end

    context 'when passed :resource' do
      let(:resource_class) { Class.new(JsonapiCompliable::Resource) }

      before do
        opts[:resource] = resource_class
      end

      it 'assigns an instance of that)resource' do
        expect(instance.resource_class).to eq(resource_class)
      end
    end
  end

  describe '#resolve' do
    context 'when polymorphic' do
      let(:opts)       { { polymorphic: true } }
      let(:query_hash) { JsonapiCompliable::Query.default_hash }
      let(:query)      { double(zero_results?: false, to_hash: { foo: query_hash }) }
      let(:parents)    { [{ id: 1, type: 'foo' }, { id: 2, type: 'bar' }] }
      let(:foo_resource) do
        Class.new(JsonapiCompliable::Resource) do
          use_adapter JsonapiCompliable::Adapters::Null
        end
      end

      before do
        instance.group_by :type

        instance.allow_sideload 'foo', resource: foo_resource do
          scope { |parents| [{ parent_id: 1 }] }
          assign do |parents, children|
            parents.each do |parent|
              parent[:child] = children.find { |c| c[:parent_id] == parent[:id] }
            end
          end
        end
      end

      it 'groups parents, then resolves that group' do
        instance.resolve(parents, query, instance.name)
        expect(parents.first[:child]).to eq({ parent_id: 1 })
      end
    end

    context 'when not polymorphic' do
      let(:parents)    { [{ id: 1 }] }
      let(:query)      { double }
      let(:results)    { [{ parent_id: 1 }] }
      let(:base_scope) { double }
      let(:scope_proc) { ->(parents) { base_scope } }
      let(:scope) do
        scope = double
        allow(scope).to receive(:resolve).and_yield(results)
        scope
      end

      before do
        instance.scope  { |parents| base_scope }
        instance.assign do |parents, children|
          parents.each do |parent|
            parent[:child] = children.find { |c| c[:parent_id] == parent[:id] }
          end
        end

        allow(JsonapiCompliable::Scope).to receive(:new)
          .and_return(scope)
      end

      it 'scopes via configured proc' do
        expect(scope).to receive(:resolve) { results }
        expect(JsonapiCompliable::Scope).to receive(:new)
          .with(base_scope, anything, query, default_paginate: false, namespace: :foo)
          .and_return(scope)
        instance.resolve(parents, query, instance.name)
      end

      it 'assigns results to parents' do
        instance.resolve(parents, query, instance.name)
        expect(parents.first[:child]).to eq({ parent_id: 1 })
      end

      context 'when passed namespace' do
        it 'passes namespace to scope builder' do
          expect(JsonapiCompliable::Scope).to receive(:new)
            .with(base_scope, anything, query, default_paginate: false, namespace: :bar)
            .and_return(scope)
          instance.resolve(parents, query, :bar)
        end
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

  describe '#associate' do
    before do
      instance.instance_variable_set(:@type, :has_many)
    end

    it 'delegates to adapter' do
      expect(instance.resource_class.config[:adapter])
        .to receive(:associate).with('parent', 'child', :foo, :has_many)
      instance.associate('parent', 'child')
    end

    context 'when a polymorphic child' do
      before do
        instance.instance_variable_set(:@parent, double(name: :parent_name))
      end

      it 'passes parent name as association name' do
        expect(instance.resource_class.config[:adapter])
          .to receive(:associate).with('parent', 'child', :parent_name, :has_many)
        instance.associate('parent', 'child')
      end
    end
  end
end
