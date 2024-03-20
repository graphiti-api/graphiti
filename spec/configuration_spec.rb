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

  # FIXME: Deprecated
  describe "when rails is defined" do
    let(:logger) { double(debug?: false) }

    let(:rails) do
      double(root: Pathname.new("/foo/bar"), logger: logger)
    end

    before do
      stub_const("::Rails", rails)
      Graphiti.instance_variable_set(:@config, nil)
    end

    after do
      Graphiti.instance_variable_set(:@config, nil)
    end

    describe "#schema_path" do
      it "defaults" do
        expect(Graphiti.config.schema_path.to_s)
          .to eq("/foo/bar/public/schema.json")
      end
    end

    describe "#debug" do
      subject { Graphiti.config.debug }

      # FIXME: Deprecated
      context "when rails logger is debug level" do
        let(:logger) { double(debug?: true) }

        it { is_expected.to eq(true) }
      end

      # FIXME: Deprecated
      context "when rails logger is not debug level" do
        it { is_expected.to eq(false) }
      end
    end

    it "sets the graphiti logger to the rails logger" do
      Graphiti.config
      expect(Graphiti.logger).to eq(rails.logger)
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

    # FIXME: Deprecated
    context "when Rails is defined" do
      before do
        rails = double(root: Pathname.new("/foo/bar"), logger: double.as_null_object)
        stub_const("::Rails", rails)
        Graphiti.instance_variable_set(:@config, nil)
      end

      it "defaults" do
        expect(Graphiti.config.schema_path.to_s)
          .to eq("/foo/bar/public/schema.json")
      end
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
end
