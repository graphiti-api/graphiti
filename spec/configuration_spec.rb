require "spec_helper"
require "pathname"

RSpec.describe Graphiti::Configuration do
  RSpec.shared_context "with config" do |name|
    around do |e|
      orig = Graphiti.config.send(name)
      begin
        e.run
      ensure
        Graphiti.config.send(:"#{name}=", orig)
      end
    end
  end

  around do |e|
    orig = Graphiti.instance_variable_get(:@config)
    Graphiti.instance_variable_set(:@config, nil)

    begin
      e.run
    ensure
      Graphiti.instance_variable_set(:@config, orig)
    end
  end

  describe "#debug=" do
    it "toggles Debugger.enabled" do
      Graphiti.config.debug = true
      expect(Graphiti::Debugger.enabled).to eq(true)
      Graphiti.config.debug = false
      expect(Graphiti::Debugger.enabled).to eq(false)
    end
  end

  describe "#debug_models=" do
    it "toggles Debugger.enabled" do
      Graphiti.config.debug_models = true
      expect(Graphiti::Debugger.debug_models).to eq(true)
      Graphiti.config.debug_models = false
      expect(Graphiti::Debugger.debug_models).to eq(false)
    end
  end

  describe "#schema_path" do
    after do
      Graphiti.config.schema_path = nil
    end

    it "raises error when not set" do
      expect {
        Graphiti.config.schema_path
      }.to raise_error(/No schema_path defined/)
    end

    it "returns value when value set" do
      Graphiti.config.schema_path = "foo"
      expect(Graphiti.config.schema_path).to eq("foo")
    end
  end

  describe "#respond_to" do
    include_context "with config", :respond_to

    it "defaults" do
      expect(Graphiti.config.respond_to)
        .to match_array([:json, :jsonapi, :xml])
    end

    it "is overridable" do
      Graphiti.configure do |c|
        c.respond_to = [:foo]
      end
      expect(Graphiti.config.respond_to).to eq([:foo])
    end
  end

  describe "#concurrency" do
    include_context "with config", :concurrency

    it "defaults" do
      expect(Graphiti.config.concurrency).to eq(false)
    end

    it "is overridable" do
      Graphiti.configure do |c|
        c.concurrency = true
      end
      expect(Graphiti.config.concurrency).to eq(true)
    end
  end

  describe "#concurrency_max_threads" do
    include_context "with config", :concurrency_max_threads

    it "defaults" do
      expect(Graphiti.config.concurrency_max_threads).to eq(4)
    end

    it "is overridable" do
      Graphiti.configure do |c|
        c.concurrency_max_threads = 1
      end
      expect(Graphiti.config.concurrency_max_threads).to eq(1)
    end
  end

  describe "#raise_on_missing_sideload" do
    include_context "with config", :raise_on_missing_sideload

    it "defaults" do
      expect(Graphiti.config.raise_on_missing_sideload).to eq(true)
    end

    it "is overridable" do
      Graphiti.configure do |c|
        c.raise_on_missing_sideload = false
      end
      expect(Graphiti.config.raise_on_missing_sideload).to eq(false)
    end
  end

  describe "deprecated resource-level settings" do
    around do |e|
      relationship_links = Graphiti::Resource.relationship_links
      page_links = Graphiti::Resource.page_links
      typecast_reads = Graphiti::Resource.typecast_reads
      e.run
    ensure
      Graphiti::Resource.relationship_links = relationship_links
      Graphiti::Resource.page_links = page_links
      Graphiti::Resource.typecast_reads = typecast_reads
    end

    describe "#typecast_reads" do
      it "maps to Resource.typecast_reads" do
        Graphiti.config.typecast_reads = false
        expect(Graphiti::Resource.typecast_reads).to eq(false)
        expect(Graphiti.config.typecast_reads).to eq(false)
      end
    end

    describe "#links_on_demand" do
      it "maps to Resource.relationship_links" do
        Graphiti.config.links_on_demand = true
        expect(Graphiti::Resource.relationship_links).to eq(:on_demand)
        expect(Graphiti.config.links_on_demand).to eq(true)

        Graphiti.config.links_on_demand = false
        expect(Graphiti::Resource.relationship_links).to eq(true)
        expect(Graphiti.config.links_on_demand).to eq(false)
      end
    end

    describe "#pagination_links" do
      it "maps to Resource.page_links" do
        Graphiti.config.pagination_links = true
        expect(Graphiti::Resource.page_links).to eq(true)
        expect(Graphiti.config.pagination_links).to eq(true)
      end

      it "does not clobber :on_demand" do
        Graphiti.config.pagination_links_on_demand = true
        Graphiti.config.pagination_links = false
        expect(Graphiti::Resource.page_links).to eq(:on_demand)
      end
    end

    describe "#pagination_links_on_demand" do
      it "maps to Resource.page_links" do
        Graphiti.config.pagination_links_on_demand = true
        expect(Graphiti::Resource.page_links).to eq(:on_demand)
        expect(Graphiti.config.pagination_links_on_demand).to eq(true)

        Graphiti.config.pagination_links_on_demand = false
        expect(Graphiti::Resource.page_links).to eq(false)
      end
    end
  end

  describe "#cache_rendering" do
    it "defaults" do
      expect(Graphiti.config.cache_rendering?).to eq(false)
    end

    it "is settable" do
      Graphiti.configure do |c|
        c.cache_rendering = true
      end
      Graphiti.cache = double(fetch: nil) # looks like a cache store
      expect(Graphiti.config.cache_rendering?).to eq(true)
    end

    it "warns about not being configured correctly if cache_rendering is true without Graphiti.cache set up" do
      Graphiti.cache = nil
      Graphiti.configure do |c|
        c.cache_rendering = true
      end

      expect { Graphiti.config.cache_rendering? }.to raise_error(/You must configure a cache store in order to use cache_rendering/)
    end
  end
end
