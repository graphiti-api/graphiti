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

      context "but no parents were found" do
        let(:results) { [] }

        it "does not resolve the sideload" do
          expect(sideload).to_not receive(:resolve)
          instance.resolve_sideloads(results)
        end
      end
    end
  end
end
