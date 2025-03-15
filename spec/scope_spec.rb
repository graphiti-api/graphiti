require "spec_helper"

RSpec.describe Graphiti::Scope do
  let(:object) { double.as_null_object }
  let(:params) { {} }
  let(:query) { Graphiti::Query.new(resource, params) }
  let(:instance) { described_class.new(object, resource, query) }

  let(:resource) do
    Class.new(PORO::EmployeeResource) {
      self.default_page_size = 1
    }.new
  end
  let(:results) { [] }

  before do
    allow(resource).to receive(:resolve) { results }
  end

  describe "#resolve" do
    it "resolves via resource" do
      # object gets modified in the Scope's constructor
      objekt = instance.instance_variable_get(:@object)
      expect(resource).to receive(:resolve).with(objekt).and_return(objekt)
      instance.resolve
    end

    it "returns results" do
      expect(instance.resolve).to eq([])
    end

    context "when sideloading" do
      let(:sideload) { double(shared_remote?: false, name: :positions) }
      let(:results) { [double.as_null_object] }

      before do
        params[:include] = {positions: {}}
        objekt = instance.instance_variable_get(:@object)
        allow(resource).to receive(:resolve).with(objekt) { results }
      end

      context "when the requested sideload exists on the resource" do
        before do
          allow(resource.class).to receive(:sideload).with(:positions) { sideload }
        end

        it "resolves the sideload" do
          expect(sideload).to receive(:resolve)
            .with(results, query.sideloads[:positions], resource)
          instance.resolve
        end

        context "but no parents were found" do
          let(:results) { [] }

          it "does not resolve the sideload" do
            expect(sideload).to_not receive(:resolve)
            instance.resolve
          end
        end
      end
    end

    context "when 0 results requested" do
      before do
        allow(query).to receive(:zero_results?) { true }
      end

      it "returns empty array" do
        expect(instance.resolve).to eq([])
      end
    end
  end

  describe "#resolve_sideloads" do
    let(:sideload) { double(shared_remote?: false, name: :positions) }
    let(:results) { [double.as_null_object] }

    before do
      params[:include] = {positions: {}}
      objekt = instance.instance_variable_get(:@object)
      allow(resource).to receive(:resolve).with(objekt) { results }
    end

    context "when the requested sideload exists on the resource" do
      before do
        allow(resource.class).to receive(:sideload).with(:positions) { sideload }
      end

      it "resolves the sideload" do
        expect(sideload).to receive(:resolve)
          .with(results, query.sideloads[:positions], resource)
        instance.resolve_sideloads(results)
      end

      context "with concurrency" do
        let(:before_sideload) { double("BeforeSideload", call: nil) }

        before { allow(Graphiti.config).to receive(:concurrency).and_return(true) }
        before { allow(Graphiti.config).to receive(:before_sideload).and_return(before_sideload) }

        it "closes db connections" do
          allow(sideload).to receive(:resolve).and_return(sideload)

          expect(resource.adapter).to receive(:close)
          instance.resolve_sideloads(results)
        end

        it "calls configiration.before_sideload with context" do
          Graphiti.context[:tenant_id] = 1
          allow(sideload).to receive(:resolve).and_return(sideload)
          expect(before_sideload).to receive(:call).with(hash_including(tenant_id: 1))
          instance.resolve_sideloads(results)
        end
      end

      context "without concurrency" do
        before { allow(Graphiti.config).to receive(:concurrency).and_return(false) }

        it "does not close db connection" do
          allow(sideload).to receive(:resolve).and_return(sideload)

          expect(resource.adapter).not_to receive(:close)
          instance.resolve_sideloads(results)
        end
      end

      context "but no parents were found" do
        let(:results) { [] }

        it "does not resolve the sideload" do
          expect(sideload).to_not receive(:resolve)
          instance.resolve_sideloads(results)
        end
      end
    end
  end

  describe "cache_key" do
    let(:employee1) {
      time = Time.parse("2022-06-24 16:36:00.000000000 -0500")
      double(cache_key: "employee/1", cache_key_with_version: "employee/1-#{time.to_i}", updated_at: time).as_null_object
    }

    let(:employee2) {
      time = Time.parse("2022-06-24 16:37:00.000000000 -0500")
      double(cache_key: "employee/2", cache_key_with_version: "employee/2-#{time.to_i}", updated_at: time).as_null_object
    }

    it "generates a stable key" do
      instance1 = described_class.new(employee1, resource, query)
      instance2 = described_class.new(employee1, resource, query)

      expect(instance1.cache_key).to be_present
      expect(instance1.cache_key).to eq(instance2.cache_key)
    end

    it "only caches off of the scoped object " do
      instance1 = described_class.new(employee1, resource, query)
      instance2 = described_class.new(employee1, resource, Graphiti::Query.new(resource, {extra_fields: {positions: ["foo"]}}))

      expect(instance1.cache_key).to be_present
      expect(instance2.cache_key).to be_present
      expect(instance1.cache_key).to eq(instance2.cache_key)

      expect(instance1.cache_key_with_version).to be_present
      expect(instance2.cache_key_with_version).to be_present
      expect(instance1.cache_key_with_version).to eq(instance2.cache_key_with_version)
    end

    it "generates a different key with a different scope query" do
      instance1 = described_class.new(employee1, resource, query)
      instance2 = described_class.new(employee2, resource, query)
      expect(instance1.cache_key).to be_present
      expect(instance2.cache_key).to be_present
      expect(instance1.cache_key).not_to eq(instance2.cache_key)

      expect(instance1.cache_key_with_version).to be_present
      expect(instance2.cache_key_with_version).to be_present
      expect(instance1.cache_key_with_version).not_to eq(instance2.cache_key)
    end
  end
end
