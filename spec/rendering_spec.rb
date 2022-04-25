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
    PORO::Department.create(name: "dep1", description: "dep1desc")
  end
  let!(:department2) do
    PORO::Department.create(name: "dep2", description: "dep2desc")
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

    it "can render _type as jsonapi type when requested" do
      params[:fields] = {employees: "first_name,_type", positions: "_type"}
      json = JSON.parse(proxy.to_json)
      expect(json["data"][0]["_type"]).to eq("employees")
      expect(json["data"][0]["positions"][0]["_type"]).to eq("positions")
    end

    context "when requesting __typename" do
      it "works" do
        params[:fields] = {
          employees: "first_name,__typename",
          positions: "__typename"
        }
        json = JSON.parse(proxy.to_json)
        expect(json["data"][0]["__typename"]).to eq("POROEmployee")
        expect(json["data"][0]["positions"][0]["__typename"])
          .to eq("POROPosition")
      end

      context "and the resource is a polymorphic subclass" do
        before do
          PORO::Mastercard.create
        end

        it "picks the subclass name" do
          params = {fields: {mastercards: "__typename"}}
          json = PORO::MastercardResource.all(params).as_json[:data]
          expect(json[0][:__typename]).to eq("POROMastercard")
        end
      end
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
          "department" => {"id" => "1", "name" => "dep1", "description" => "dep1desc"}
        ])
        expect(json[1]["positions"]).to eq([
          "id" => "2",
          "title" => "title2",
          "rank" => 2,
          "department" => {"id" => "2", "name" => "dep2", "description" => "dep2desc"}
        ])
      end

      context "and the relationship is empty" do
        context "for a to_many" do
          before do
            PORO::DB.data[:positions] = []
          end

          it "renders empty array" do
            expect(json[0]["positions"]).to eq([])
          end
        end

        context "for a to_one" do
          before do
            PORO::DB.data[:departments] = []
          end

          it "renders nil" do
            expect(json[0]["positions"][0]["department"]).to be_nil
          end
        end
      end

      context "when the relationship is to a polymorphic resource" do
        before do
          PORO::Visa.create employee_id: employee2.id, number: 1
          gold = PORO::GoldVisa.create employee_id: employee2.id, number: 2
          PORO::VisaReward.create visa_id: gold.id
          PORO::Mastercard.create employee_id: employee2.id, number: 3
          params[:include] = "credit_cards.on__gold_visas--visa_rewards"
        end

        # NB - both visa and gold visa support the relationship
        # But we only see it on gold visas
        it "respects type-specific includes" do
          cards = json[1]["credit_cards"]
          expect(cards[0].keys).to eq(%w[id number description visa_only_attr])
          expect(cards[1].keys)
            .to eq(%w[id number description visa_only_attr visa_rewards])
          expect(cards[2].keys).to eq(%w[id number description])
          expect(cards[1]["visa_rewards"]).to eq([{
            "id" => "1",
            "points" => nil
          }])
        end
      end

      context "and the top-level resource is polymorphic" do
        before do
          PORO::Visa.create employee_id: employee2.id, number: 1
          gold = PORO::GoldVisa.create employee_id: employee2.id, number: 2
          PORO::VisaReward.create visa_id: gold.id
          PORO::Mastercard.create employee_id: employee2.id, number: 3
        end

        it "respects type-specific includes" do
          proxy = PORO::CreditCardResource.all({
            include: "on__gold_visas--visa_rewards"
          })
          json = JSON.parse(proxy.to_json)
          cards = json["data"]
          expect(cards[0].keys).to eq(%w[id number description visa_only_attr])
          expect(cards[1].keys)
            .to eq(%w[id number description visa_only_attr visa_rewards])
          expect(cards[2].keys).to eq(%w[id number description])
          expect(cards[1]["visa_rewards"]).to eq([{
            "id" => "1",
            "points" => nil
          }])
        end
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

      context "on a relationship" do
        context "via type" do
          before do
            params[:include] = "positions,positions.department"
            params[:fields] = {departments: "description"}
          end

          it "works" do
            expect(json[0]["positions"][0]["department"])
              .to eq({"description" => "dep1desc", "id" => "1"})
          end
        end

        context "via dot syntax" do
          before do
            params[:include] = "positions.department.positions.department"
            params[:fields] = {'positions.department.positions.department': "description"}
          end

          it "works" do
            level1 = json[0]["positions"][0]["department"]
            level2 = level1["positions"][0]["department"]
            expect(level1.keys).to match_array(%w[id name description positions])
            expect(level2.keys).to match_array(%w[id description])
          end

          context "when deeply nested, with multiple objects per type" do
            before do
              params[:include] = "positions.department.positions.department"
              params[:fields] = {"positions.department.positions.department": "description"}
              dept = PORO::Department.create(name: "anotherdept")
              PORO::Position.create \
                employee_id: employee1.id,
                department_id: dept.id
            end

            it "works" do
              level1a = json[0]["positions"][0]["department"]
              level1b = json[0]["positions"][1]["department"]
              level2a = level1a["positions"][0]["department"]
              level2b = level1b["positions"][0]["department"]
              expect(level1a.keys).to match_array(%w[id name description positions])
              expect(level1b.keys).to match_array(%w[id name description positions])
              expect(level2a.keys).to match_array(%w[id description])
              expect(level2b.keys).to match_array(%w[id description])
            end

            context "and there is also a type-based fieldset" do
              before do
                params[:fields][:departments] = "name"
              end

              it "applies, but the more specific dot-syntax wins" do
                level1a = json[0]["positions"][0]["department"]
                level1b = json[0]["positions"][1]["department"]
                level2a = level1a["positions"][0]["department"]
                level2b = level1b["positions"][0]["department"]
                expect(level1a.keys).to match_array(%w[id name positions])
                expect(level1b.keys).to match_array(%w[id name positions])
                expect(level2a.keys).to match_array(%w[id description])
                expect(level2b.keys).to match_array(%w[id description])
              end
            end
          end
        end
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

    context "when the resource is polymorphic" do
      let!(:visa) { PORO::Visa.create(number: "1") }
      let!(:gold_visa) { PORO::GoldVisa.create(number: "2") }
      let!(:mastercard) { PORO::Mastercard.create(number: "3") }

      context "with sparse fieldsets" do
        let(:json) do
          JSON.parse(PORO::CreditCardResource.all(cc_params).to_json)
        end

        context "when only child specified" do
          let(:cc_params) { {fields: {mastercards: "description"}} }

          it "works" do
            expect(json["data"]).to eq([
              {
                "id" => "1",
                "number" => 1,
                "description" => "visa description",
                "visa_only_attr" => "visa only"
              },
              {
                "id" => "1",
                "number" => 2,
                "description" => "visa description",
                "visa_only_attr" => "visa only"
              },
              {
                "id" => "1",
                "description" => "mastercard description"
              }
            ])
          end
        end

        context "when only parent specified" do
          let(:cc_params) { {fields: {credit_cards: "number"}} }

          it "works" do
            expect(json["data"]).to eq([
              {
                "id" => "1",
                "number" => 1
              },
              {
                "id" => "1",
                "number" => 2
              },
              {
                "id" => "1",
                "number" => 3
              }
            ])
          end
        end

        context "when both parent and child are specified" do
          let(:cc_params) { {fields: {credit_cards: "number", mastercards: "description"}} }

          it "combines the types" do
            expect(json["data"]).to eq([
              {
                "id" => "1",
                "number" => 1
              },
              {
                "id" => "1",
                "number" => 2
              },
              {
                "id" => "1",
                "number" => 3,
                "description" => "mastercard description"
              }
            ])
          end
        end
      end
    end

    describe "in graphql context" do
      let(:json) { proxy.as_graphql }

      context "and the data is an array" do
        it "sets the top level key as the jsonapi type" do
          expect(json.keys).to eq([:employees])
        end

        context "when manual graphql_entrypoint" do
          before do
            resource.graphql_entrypoint = :exemplaryEmployees
          end

          it "matches the entrypoint" do
            expect(json.keys).to eq([:exemplaryEmployees])
          end
        end
      end

      context "and the data is a single object" do
        it "sets the top level key as the jsonapi type" do
          json = resource.find(id: employee1.id).as_graphql
          expect(json.keys).to eq([:employee])
        end

        context "when manual graphql_entrypoint" do
          before do
            resource.graphql_entrypoint = :exemplaryEmployees
          end

          it "matches the singularized entrypoint" do
            json = resource.find(id: employee1.id).as_graphql
            expect(json.keys).to eq([:exemplaryEmployee])
          end
        end
      end

      context "when the id is not requested" do
        before do
          params[:include] = "positions"
          params[:fields] = {employees: "first_name", positions: "title"}
        end

        it "is not returned" do
          expect(json[:employees][:nodes][0]).to eq({
            firstName: "John",
            positions: {nodes: [{title: "title1"}]}
          })
        end
      end

      context "when the id is requested" do
        before do
          params[:include] = "positions"
          params[:fields] = {employees: "id,first_name", positions: "id,title"}
        end

        it "is returned" do
          expect(json[:employees][:nodes][0]).to eq({
            id: employee1.id.to_s,
            firstName: "John",
            positions: {nodes: [{id: position1.id.to_s, title: "title1"}]}
          })
        end
      end

      context "when _type is not requested" do
        before do
          params[:include] = "positions"
          params[:fields] = {employees: "first_name", positions: "title"}
        end

        it "is not returned" do
          expect(json[:employees][:nodes][0]).to eq({
            firstName: "John",
            positions: {nodes: [{title: "title1"}]}
          })
        end
      end

      context "when the _type is requested" do
        before do
          params[:include] = "positions"
          params[:fields] = {employees: "_type,first_name", positions: "_type,title"}
        end

        it "is returned" do
          expect(json[:employees][:nodes][0]).to eq({
            _type: "employees",
            firstName: "John",
            positions: {nodes: [{_type: "positions", title: "title1"}]}
          })
        end
      end

      context "when a multi-word attribute" do
        before do
          position_resource = Class.new(PORO::PositionResource) do
            def self.name
              "PORO::PositionResource"
            end
            attribute :multi_word, :string do
              "foo"
            end
          end
          resource.has_many :positions, resource: position_resource
          params[:include] = "positions"
          params[:fields] = {employees: "first_name", positions: "multi_word"}
        end

        it "is camelized" do
          expect(json[:employees][:nodes][0]).to eq({
            firstName: "John",
            positions: {nodes: [{multiWord: "foo"}]}
          })
        end
      end

      context "when a multi-word relationship" do
        before do
          position_resource = Class.new(PORO::PositionResource) do
            def self.name
              "PORO::PositionResource"
            end
          end
          position_resource.belongs_to :important_department,
            resource: PORO::DepartmentResource
          resource.has_many :important_positions,
            resource: position_resource
          params[:include] = "important_positions.important_department"
        end

        it "is camelized" do
          employee = json[:employees][:nodes][0]
          expect(employee[:importantPositions][:nodes]).to eq([{
            rank: 1,
            title: "title1",
            importantDepartment: {
              description: "dep1desc",
              name: "dep1"
            }
          }])
        end
      end

      context 'when a multi-word stat' do
        before do
          resource.stat multi_word: [:average] do
            average do
              10
            end
          end
          params[:stats] = {multi_word: "average"}
        end

        it "is camelized" do
          expect(json[:employees][:stats].keys.first).to eq(:multiWord)
        end
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
          "department" => {"id" => "1", "name" => "dep1", "description" => "dep1desc"}
        ])
        expect(xml[1]["positions"]).to eq([
          "id" => "2",
          "title" => "title2",
          "rank" => 2,
          "department" => {"id" => "2", "name" => "dep2", "description" => "dep2desc"}
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
