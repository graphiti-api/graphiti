require 'spec_helper'

RSpec.describe Graphiti::Configuration do
  RSpec.shared_context 'with config' do |name|
    around do |e|
      orig = Graphiti.config.send(name)
      begin
        e.run
      ensure
        Graphiti.config.send(:"#{name}=", orig)
      end
    end
  end

  describe '#schema_path' do
    after do
      Graphiti.config.schema_path = nil
    end

    it 'raises error when not set' do
      expect {
        Graphiti.config.schema_path
      }.to raise_error(/No schema_path defined/)
    end

    it 'returns value when value set' do
      Graphiti.config.schema_path = 'foo'
      expect(Graphiti.config.schema_path).to eq('foo')
    end

    context 'when Rails is defined' do
      before do
        rails = double(root: '/foo/bar')
        stub_const('::Rails', rails)
        Graphiti.instance_variable_set(:@config, nil)
      end

      it 'defaults' do
        expect(Graphiti.config.schema_path)
          .to eq('/foo/bar/public/schema.json')
      end
    end
  end

  describe '#respond_to' do
    include_context 'with config', :respond_to

    it 'defaults' do
      expect(Graphiti.config.respond_to)
        .to match_array([:json, :jsonapi, :xml])
    end

    it 'is overridable' do
      Graphiti.configure do |c|
        c.respond_to = [:foo]
      end
      expect(Graphiti.config.respond_to).to eq([:foo])
    end
  end

  describe '#concurrency' do
    include_context 'with config', :concurrency

    it 'defaults' do
      expect(Graphiti.config.concurrency).to eq(false)
    end

    it 'is overridable' do
      Graphiti.configure do |c|
        c.concurrency = true
      end
      expect(Graphiti.config.concurrency).to eq(true)
    end
  end

  describe '#raise_on_missing_sideload' do
    include_context 'with config', :raise_on_missing_sideload

    it 'defaults' do
      expect(Graphiti.config.raise_on_missing_sideload).to eq(true)
    end

    it 'is overridable' do
      Graphiti.configure do |c|
        c.raise_on_missing_sideload = false
      end
      expect(Graphiti.config.raise_on_missing_sideload).to eq(false)
    end
  end
end
