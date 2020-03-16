require "spec_helper"

RSpec.describe "serialization" do
  include_context "resource testing"
  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end
  let(:base_scope) { {type: :employees} }

  let!(:employee1) do
    PORO::Employee.create first_name: "John",
                          last_name: "Doe",
                          age: 33
  end
  let!(:employee2) do
    PORO::Employee.create first_name: "Jane",
                          last_name: "Dougherty",
                          age: 44
  end
  let!(:position1) do
    PORO::Position.create title: "title1",
                          rank: 1,
                          employee_id: 1,
                          department_id: 1
  end
  let!(:position2) do
    PORO::Position.create title: "title2",
                          rank: 2,
                          employee_id: 2,
                          department_id: 2
  end
  let!(:department1) do
    PORO::Department.create(name: "dep1")
  end
  let!(:department2) do
    PORO::Department.create(name: "dep2")
  end

  before do
    params[:include] = "positions.department"
  end

  def json
    JSON.parse(proxy.to_json)["data"]
  end

  def xml
    xml = proxy.to_xml
    Hash.from_xml(xml)["data"]["data"]
  end

  context "when rendering jsonapi" do
    let(:jsonapi) { JSON.parse(proxy.to_jsonapi) }

    context "when rendering pagination links" do
      before do
        allow(proxy).to receive(:pagination).and_return(pagination_delegate)
      end
      let(:pagination_delegate) { double(links?: true, links: pagination_links) }
      let(:pagination_links) { {"page" => {"number" => 1, "size" => 20}} }
      let(:links) { jsonapi["links"] }
      it "works" do
        expect(links).to eq(pagination_links)
      end
    end
  end

  context "when rendering vanilla json" do
    it "works" do
      params.delete(:include)
      expect(json).to be_a(Array)
      expect(json.length).to eq(2)
      expect(json[0]).to eq({
        "id" => "1",
        "first_name" => "John",
        "last_name" => "Doe",
        "age" => 33
      })
      expect(json[1]).to eq({
        "id" => "2",
        "first_name" => "Jane",
        "last_name" => "Dougherty",
        "age" => 44
      })
    end

    it "accepts runtime options" do
      json = JSON.parse(proxy.to_json(meta: {foo: "bar"}))
      expect(json["meta"]).to eq("foo" => "bar")
    end

    it "does not blow up on nils" do
      PORO::DB.data[:departments] = []
      json = JSON.parse(proxy.to_json)
      position = json["data"][0]["positions"][0]
      expect(position).to have_key("department")
      expect(position["department"]).to be_nil
    end

    class RenderResults < SimpleDelegator
      attr_accessor :meta

      def initialize(array, meta:)
        super(array)
        @meta = meta
      end
    end

    context "when resolved data has meta" do
      before do
        resource.class_eval do
          def resolve(scope)
            RenderResults.new(super, meta: {foo: "bar"})
          end
        end
      end

      it "is returned in the response" do
        json = JSON.parse(proxy.to_jsonapi)
        expect(json["meta"]).to eq({"foo" => "bar"})
      end
    end

    context "when sideloading" do
      it "works" do
        expect(json[0]["positions"]).to eq([
          "id" => "1",
          "title" => "title1",
          "rank" => 1,
          "department" => {"id" => "1", "name" => "dep1"}
        ])
        expect(json[1]["positions"]).to eq([
          "id" => "2",
          "title" => "title2",
          "rank" => 2,
          "department" => {"id" => "2", "name" => "dep2"}
        ])
      end
    end

    context "when sparse fields" do
      before do
        params[:fields] = {employees: "first_name", positions: "rank"}
      end

      it "works" do
        expect(json[0].keys).to eq(%w[id first_name positions])
        expect(json[0]["positions"][0].keys).to eq(%w[id rank department])
      end
    end

    context "when extra fields" do
      before do
        params[:extra_fields] = {employees: "worth", positions: "score"}
      end

      it "works" do
        expect(json[0]["worth"]).to eq(100)
        expect(json[0]["positions"][0]["score"]).to eq(200)
      end
    end

    context "when not rendering meta" do
      it "does not render the meta key" do
        json = JSON.parse(proxy.to_json)
        expect(json).to_not have_key("meta")
      end
    end

    context "when rendering meta" do
      before do
        params[:stats] = {total: "count"}
      end

      it "works" do
        json = JSON.parse(proxy.to_json)
        expect(json["meta"]).to eq({
          "stats" => {"total" => {"count" => "poro_count_total"}}
        })
      end

      it "merges runtime meta" do
        json = JSON.parse(proxy.to_json(meta: {foo: "bar"}))
        expect(json["meta"]).to eq({
          "foo" => "bar",
          "stats" => {"total" => {"count" => "poro_count_total"}}
        })
      end
    end
  end

  context "when rendering xml" do
    it "works" do
      params.delete(:include)
      expect(xml).to be_a(Array)
      expect(xml.length).to eq(2)
      expect(xml[0]).to eq({
        "id" => "1",
        "first_name" => "John",
        "last_name" => "Doe",
        "age" => 33
      })
      expect(xml[1]).to eq({
        "id" => "2",
        "first_name" => "Jane",
        "last_name" => "Dougherty",
        "age" => 44
      })
    end

    it "accepts runtime options" do
      xml = Hash.from_xml(proxy.to_xml(meta: {foo: "bar"}))
      expect(xml["data"]["meta"]).to eq("foo" => "bar")
    end

    context "when sideloading" do
      it "works" do
        expect(xml[0]["positions"]).to eq([
          "id" => "1",
          "title" => "title1",
          "rank" => 1,
          "department" => {"id" => "1", "name" => "dep1"}
        ])
        expect(xml[1]["positions"]).to eq([
          "id" => "2",
          "title" => "title2",
          "rank" => 2,
          "department" => {"id" => "2", "name" => "dep2"}
        ])
      end
    end

    context "when sparse fields" do
      before do
        params[:fields] = {employees: "first_name", positions: "rank"}
      end

      it "works" do
        expect(xml[0].keys).to eq(%w[id first_name positions])
        expect(xml[0]["positions"][0].keys).to eq(%w[id rank department])
      end
    end

    context "when extra fields" do
      before do
        params[:extra_fields] = {employees: "worth", positions: "score"}
      end

      it "works" do
        expect(xml[0]["worth"]).to eq(100)
        expect(xml[0]["positions"][0]["score"]).to eq(200)
      end
    end

    context "when not rendering meta" do
      it "does not render the meta key" do
        xml = Hash.from_xml(proxy.to_xml)
        expect(xml["data"]).to_not have_key("meta")
      end
    end

    context "when rendering meta" do
      before do
        params[:stats] = {total: "count"}
      end

      it "works" do
        xml = Hash.from_xml(proxy.to_xml)["data"]
        expect(xml["meta"]).to eq({
          "stats" => {"total" => {"count" => "poro_count_total"}}
        })
      end

      it "merges runtime meta" do
        xml = Hash.from_xml(proxy.to_xml(meta: {foo: "bar"}))["data"]
        expect(xml["meta"]).to eq({
          "foo" => "bar",
          "stats" => {"total" => {"count" => "poro_count_total"}}
        })
      end
    end
  end

  context "when debug is not requested" do
    it "does not render debug json" do
      json = JSON.parse(proxy.to_json)
      expect(json).to_not have_key("meta")
    end
  end

  context "when debug is requested" do
    before do
      params[:debug] = true
    end

    context "and context does not respond to debug json method" do
      let(:graphiti_context) { OpenStruct.new }

      it "does not render debug json" do
        json = JSON.parse(proxy.to_json)
        expect(json).to_not have_key("meta")
      end
    end

    context "and context allows debug json" do
      let(:graphiti_context) do
        OpenStruct.new(allow_graphiti_debug_json?: true)
      end

      context "but debugging is disabled" do
        around do |e|
          original = ::Graphiti::Debugger.enabled
          ::Graphiti::Debugger.enabled = false
          begin
            e.run
          ensure
            ::Graphiti::Debugger.enabled = original
          end
        end

        it "does not render debug json" do
          json = JSON.parse(proxy.to_json)
          expect(json).to_not have_key("meta")
        end
      end

      context "and debugging is enabled" do
        around do |e|
          original = ::Graphiti::Debugger.enabled
          ::Graphiti::Debugger.enabled = true
          begin
            e.run
          ensure
            ::Graphiti::Debugger.enabled = original
          end
        end

        it "renders debug json" do
          json = JSON.parse(proxy.to_json)
          expect(json["meta"]["debug"]).to be_a(Array)
        end
      end
    end
  end
end
