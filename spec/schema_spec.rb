require "spec_helper"
require "fileutils"

RSpec.describe Graphiti::Schema do
  describe ".generate" do
    subject(:schema) { described_class.generate(resources) }

    let(:expected) do
      {
        resources: [
          {
            name: "Schema::EmployeeResource",
            type: "employees",
            graphql_entrypoint: "employees",
            description: "An employee of the organization",
            attributes: {
              id: {
                type: "integer_id",
                readable: true,
                writable: true,
                description: nil
              },
              first_name: {
                type: "string",
                readable: true,
                writable: true,
                description: "The employee's first name"
              }
            },
            sorts: {
              id: {},
              first_name: {}
            },
            stats: {
              total: [:count]
            },
            filters: {
              id: {
                type: "integer_id",
                operators: Graphiti::Adapters::Abstract.default_operators[:integer].map(&:to_s)
              },
              first_name: {
                type: "string",
                operators: Graphiti::Adapters::Abstract.default_operators[:string].map(&:to_s)
              },
              title: {
                type: "string",
                operators: Graphiti::Adapters::Abstract.default_operators[:string].map(&:to_s)
              }
            },
            extra_attributes: {
              net_sales: {
                type: "float",
                readable: true,
                description: "The total value of the employee's sales"
              }
            },
            relationships: {
              positions: {
                resource: "Schema::PositionResource",
                type: "has_many",
                description: nil
                # writable: true,
                # readable: true
              }
            }
          }
        ],
        endpoints: {
          "/api/v1/schema/employees": {
            actions: {
              index: {resource: "Schema::EmployeeResource"},
              show: {resource: "Schema::EmployeeResource"},
              create: {resource: "Schema::EmployeeResource"},
              update: {resource: "Schema::EmployeeResource"},
              destroy: {resource: "Schema::EmployeeResource"}
            }
          }
        },
        types: {
          integer_id: {
            kind: "scalar",
            description: "Base Type. Query/persist as integer, render as string."
          },
          string: {
            kind: "scalar",
            description: "Base Type."
          },
          uuid: {
            description: "Base Type. Like a normal string, but by default only eq/!eq and case-sensitive.",
            kind: "scalar"
          },
          string_enum: {
            description: "String enum type. Like a normal string, but only eq/!eq and case-sensitive. Limited to only the allowed values.",
            kind: "scalar"
          },
          integer_enum: {
            description: "Integer enum type. Like a normal integer, but only eq/!eq filters. Limited to only the allowed values.",
            kind: "scalar"
          },
          integer: {
            kind: "scalar",
            description: "Base Type."
          },
          big_decimal: {
            kind: "scalar",
            description: "Base Type."
          },
          float: {
            kind: "scalar",
            description: "Base Type."
          },
          boolean: {
            kind: "scalar",
            description: "Base Type."
          },
          date: {
            kind: "scalar",
            description: "Base Type."
          },
          datetime: {
            kind: "scalar",
            description: "Base Type."
          },
          hash: {
            kind: "record",
            description: "Base Type."
          },
          array: {
            kind: "array",
            description: "Base Type."
          },
          array_of_integer_ids: {
            kind: "array",
            description: "Base Type."
          },
          array_of_strings: {
            kind: "array",
            description: "Base Type."
          },
          array_of_uuids: {
            description: "Base Type.",
            kind: "array"
          },
          array_of_string_enums: {
            description: "Base Type.",
            kind: "array"
          },
          array_of_integer_enums: {
            description: "Base Type.",
            kind: "array"
          },
          array_of_integers: {
            kind: "array",
            description: "Base Type."
          },
          array_of_big_decimals: {
            kind: "array",
            description: "Base Type."
          },
          array_of_floats: {
            kind: "array",
            description: "Base Type."
          },
          array_of_dates: {
            kind: "array",
            description: "Base Type."
          },
          array_of_datetimes: {
            kind: "array",
            description: "Base Type."
          }
        }
      }
    end

    let(:application_resource) do
      Class.new(Graphiti::Resource) do
        self.endpoint_namespace = "/api/v1"
      end
    end

    let(:employee_resource) do
      pr = position_resource
      Class.new(application_resource) do
        def self.name
          "Schema::EmployeeResource"
        end
        self.type = :employees
        self.graphql_entrypoint = :employees
        self.description = "An employee of the organization"

        attribute :first_name, :string, description: "The employee's first name"
        attribute :hidden_attribute, :string, schema: false
        extra_attribute :net_sales, :float, description: "The total value of the employee's sales"

        filter :title, :string do
          eq do |scope, value|
          end
        end

        has_many :positions, resource: pr
      end
    end

    let(:position_resource) do
      Class.new(PORO::ApplicationResource) do
        def self.name
          "Schema::PositionResource"
        end
      end
    end

    let(:resources) do
      [employee_resource]
    end

    let(:test_context) do
      Class.new do
        include Graphiti::Context
      end
    end

    around do |e|
      Graphiti.config.context_for_endpoint = ->(path, action) {
        test_context
      }
      begin
        e.run
      ensure
        Graphiti.config.context_for_endpoint = nil
      end
    end

    it "has correct resources" do
      expect(schema[:resources]).to eq(expected[:resources])
    end

    it "has correct endpoints" do
      expect(schema[:endpoints]).to eq(expected[:endpoints])
    end

    it "has correct types" do
      expect(schema[:types]).to eq(expected[:types])
    end

    it "has sorted types" do
      expect(schema[:types].to_a).to eq(expected[:types].sort)
    end

    # Dynamically-created resources, e.g. remote resources
    context "when resource has missing name" do
      let(:no_name) do
        Class.new(Graphiti::Resource)
      end

      before do
        resources << no_name
      end

      it "is not included in the schema" do
        expect(schema[:resources]).to eq(expected[:resources])
      end
    end

    context "when no resources passed" do
      subject(:schema) { described_class.generate }

      around do |e|
        Graphiti.instance_variable_set(:@resources, [position_resource])
        begin
          e.run
        ensure
          Graphiti.instance_variable_set(:@resources, [])
        end
      end

      it "grabs all non-abstract descendants of Graphiti::Resource" do
        expect(schema[:resources].length).to eq(1)
        expect(schema[:resources][0][:name]).to eq("Schema::PositionResource")
      end
    end

    context "when attribute is not readable" do
      before do
        employee_resource.class_eval do
          attribute :first_name, :string, readable: false
        end
      end

      it "is reflected in the schema" do
        expect(schema[:resources][0][:attributes][:first_name][:readable])
          .to eq(false)
      end
    end

    context "when attribute is not writable" do
      before do
        employee_resource.class_eval do
          attribute :first_name, :string, writable: false
        end
      end

      it "is reflected in the schema" do
        expect(schema[:resources][0][:attributes][:first_name][:writable])
          .to eq(false)
      end
    end

    context "when attribute is not sortable" do
      before do
        employee_resource.class_eval do
          attribute :foo, :string, sortable: false
        end
      end

      it "is not in the schema" do
        expect(schema[:resources][0][:attributes]).to have_key(:foo)
        expect(schema[:resources][0][:sorts]).to_not have_key(:foo)
      end
    end

    context "when attribute is not filterable" do
      before do
        employee_resource.config[:filters] = {}
        employee_resource.class_eval do
          attribute :first_name, :string, filterable: false
        end
      end

      it "is not in the list of filters" do
        expect(schema[:resources][0][:filters]).to_not have_key(:first_name)
      end
    end

    context "when the attribute is guarded" do
      before do
        employee_resource.class_eval do
          attribute :first_name, :string, readable: :admin?
        end
      end

      it "returns :guarded, not the runtime method" do
        expect(schema[:resources][0][:attributes][:first_name][:readable])
          .to eq("guarded")
      end
    end

    context "when attribute is only sortable in one direction" do
      before do
        employee_resource.sort :foo, :string, only: :asc
      end

      it "is reflected in the schema" do
        expect(schema[:resources][0][:sorts][:foo][:only])
          .to eq(:asc)
      end
    end

    context "when filter overrides type" do
      before do
        employee_resource.filter :first_name, :integer
      end

      it "is reflected in the schema" do
        expect(schema[:resources][0][:attributes][:first_name][:type])
          .to eq("string")
        expect(schema[:resources][0][:filters][:first_name][:type])
          .to eq("integer")
      end
    end

    context "when the filter is guarded" do
      before do
        employee_resource.class_eval do
          attribute :first_name, :string, filterable: :admin?
        end
      end

      it "flags it as guarded" do
        expect(schema[:resources][0][:filters][:first_name][:guard])
          .to eq(true)
      end
    end

    context "when filter is required" do
      context "via attribute syntax" do
        before do
          employee_resource.config[:filters] = {}
          employee_resource.class_eval do
            attribute :first_name, :string, filterable: :required
          end
        end

        it "flags it as required" do
          expect(schema[:resources][0][:filters][:first_name][:required])
            .to eq(true)
        end

        it "does NOT flag as guarded" do
          expect(schema[:resources][0][:filters][:first_name])
            .to_not have_key(:guard)
        end
      end

      context "via filter syntax" do
        before do
          employee_resource.config[:filters] = {}
          employee_resource.class_eval do
            filter :first_name, :string, required: true
          end
        end

        it "flags it as required" do
          expect(schema[:resources][0][:filters][:first_name][:required])
            .to eq(true)
        end

        it "does NOT flag as guarded" do
          expect(schema[:resources][0][:filters][:first_name])
            .to_not have_key(:guard)
        end
      end
    end

    context "when attribute supports subset of filter operators via :only" do
      before do
        employee_resource.class_eval do
          filter :first_name, only: [:eq, :prefix]
        end
      end

      it "limits the list of operators for the filter" do
        expect(schema[:resources][0][:filters][:first_name][:operators])
          .to eq(%w[eq prefix])
      end
    end

    context "when attribute supports subset of operators via :except" do
      before do
        employee_resource.class_eval do
          filter :first_name, except: [:eq, :not_eq, :eql, :not_eql]
        end
      end

      it "limits the list of operators for the filter" do
        expect(schema[:resources][0][:filters][:first_name][:operators])
          .to eq([
            "prefix",
            "not_prefix",
            "suffix",
            "not_suffix",
            "match",
            "not_match"
          ])
      end
    end

    context "when the filter is singular" do
      before do
        employee_resource.class_eval do
          filter :first_name, single: true
        end
      end

      it "is marked as such" do
        expect(schema[:resources][0][:filters][:first_name][:single])
          .to eq(true)
      end
    end

    context "when the filter has a allowlist" do
      before do
        employee_resource.class_eval do
          filter :first_name, allow: [:foo]
        end
      end

      it "is marked as such" do
        expect(schema[:resources][0][:filters][:first_name][:allow])
          .to eq(["foo"])
      end
    end

    context "when a filter group" do
      before do
        employee_resource.filter_group [:first_name, :last_name],
          required: :any
      end

      it "is present in the schema" do
        expect(schema[:resources][0][:filter_group]).to eq({
          names: [:first_name, :last_name],
          required: :any
        })
      end
    end

    context "when the attribute is a string enum" do
      before do
        employee_resource.class_eval do
          attribute :enum_first_name, :string_enum, allow: [:foo]
        end
      end

      it "reflects the values in the filters" do
        expect(schema[:resources][0][:filters][:enum_first_name][:allow])
          .to eq(["foo"])
      end
    end

    context "when the filter has a denylist" do
      before do
        employee_resource.class_eval do
          filter :first_name, deny: [:bar]
        end
      end

      it "is marked as such" do
        expect(schema[:resources][0][:filters][:first_name][:deny])
          .to eq(["bar"])
      end
    end

    context "when the filter has dependencies" do
      before do
        employee_resource.filter :first_name, :string, dependent: [:foo]
      end

      it "reflects them in the schema" do
        expect(schema[:resources][0][:filters][:first_name][:dependencies])
          .to eq(["foo"])
      end
    end

    context "when the attribute is schema: false then .filter called" do
      before do
        employee_resource.filter :hidden_attribute
      end

      it "appears in the schema" do
        expect(schema[:resources][0][:filters].key?(:hidden_attribute))
          .to eq(true)
      end

      context "when passed schema: false at filter level" do
        before do
          employee_resource.filter :hidden_attribute, schema: false
        end

        it "does not appear in the schema" do
          expect(schema[:resources][0][:filters].key?(:hidden_attribute))
            .to eq(false)
        end
      end
    end

    context "when attribute changes to schema true" do
      before do
        employee_resource.class_eval do
          attribute :hidden_attribute, :string, schema: true
        end
      end

      it "is readable" do
        expect(schema[:resources][0][:attributes][:hidden_attribute][:readable])
          .to eq(true)
      end
    end

    context "when extra attribute is guarded" do
      before do
        employee_resource.class_eval do
          extra_attribute :net_sales, :float, readable: :admin?
        end
      end

      it "returns :guarded, not the runtime method" do
        expect(schema[:resources][0][:extra_attributes][:net_sales][:readable])
          .to eq("guarded")
      end
    end

    context "when extra attribute has schema false" do
      before do
        employee_resource.class_eval do
          extra_attribute :net_sales, :float, schema: false
        end
      end

      it "is not in the list of extra_attributes" do
        expect(schema[:resources][0][:extra_attributes]).not_to have_key(:net_sales)
      end
    end

    context "when extra attribute is also a filter" do
      before do
        employee_resource.class_eval do
          extra_attribute :net_sales, :float, filterable: true
          filter :net_sales, only: [:eq]
        end
      end

      it "is in the list of filters" do
        expect(schema[:resources][0][:filters]).to have_key(:net_sales)
      end
    end

    context "when extra attribute is also a sort" do
      before do
        employee_resource.class_eval do
          extra_attribute :net_sales, :float, sortable: true
          sort :net_sales
        end
      end

      it "is in the list of sorts" do
        expect(schema[:resources][0][:sorts]).to have_key(:net_sales)
      end
    end

    context "when an additional statistic/calculations" do
      before do
        employee_resource.stat age: [:average, :sum]
      end

      it "is added to the schema" do
        expect(schema[:resources][0][:stats]).to eq({
          total: [:count],
          age: [:average, :sum]
        })
      end
    end

    context "when a default sort" do
      before do
        employee_resource.default_sort = [{foo: :asc}]
      end

      it "is present in the resource schema" do
        expect(schema[:resources][0][:default_sort])
          .to eq([{"foo" => "asc"}])
      end
    end

    context "when a default page size" do
      before do
        employee_resource.default_page_size = 10
      end

      it "is present in the resource schema" do
        expect(schema[:resources][0][:default_page_size]).to eq(10)
      end
    end

    context "when sideload is remote" do
      before do
        employee_resource.has_many :foos,
          remote: "http://foo.com/api/v1/foos"
      end

      it "adds the associated resource to the schema correctly" do
        schema
        expect(schema[:resources][0][:relationships][:foos]).to eq({
          description: nil,
          resource: "Schema::EmployeeResource.foos.remote",
          type: "has_many"
        })
      end
    end

    # todo still need local rels
    context "when resource is remote" do
      before do
        employee_resource.remote = "http://foo.com"
      end

      it "is added to the schema correctly" do
        expect(schema[:resources][0]).to eq({
          description: "An employee of the organization",
          name: "Schema::EmployeeResource",
          remote: "http://foo.com",
          relationships: {
            positions: {
              description: nil,
              resource: "Schema::PositionResource",
              type: "has_many"
            }
          }
        })
      end
    end

    context "with multiple remote resources" do
      let(:resources) { [position_resource, employee_resource] }

      before do
        employee_resource.remote = "http://foo.com"
        position_resource.remote = "http://bar.com"
      end

      it "is added to the schema sorted by name" do
        expect(schema[:resources].map { |resource| resource[:name] })
          .to eq(["Schema::EmployeeResource", "Schema::PositionResource"])
      end
    end

    context "when sideload is single: true" do
      before do
        employee_resource.has_many :positions,
          single: true,
          resource: position_resource
      end

      it "is reflected in the schema" do
        expect(schema[:resources][0][:relationships][:positions][:single])
          .to eq(true)
      end
    end

    context "when sideload allowlist" do
      before do
        test_context.sideload_allowlist = {
          index: {positions: "department"}
        }
      end

      it "is reflected in the schema" do
        endpoint = schema[:endpoints][:"/api/v1/schema/employees"]
        expect(endpoint[:actions][:index][:sideload_allowlist]).to eq({
          positions: {department: {}}
        })
      end
    end

    context "when a resource is remote" do
      before do
        employee_resource.remote = "http://foo.com/employees"
      end

      it "does not add endpoints to the schema" do
        expect(schema[:endpoints]).to eq({})
      end
    end

    context "when 2 resources, same path" do
      let(:employee_search_resource) do
        Class.new(application_resource) do
          def self.name
            "Schema::EmployeeSearchResource"
          end
          primary_endpoint "/schema/employees", [:index]
        end
      end

      before do
        resources.unshift(employee_search_resource)
      end

      context "and there is no conflict" do
        before do
          employee_resource.endpoint[:actions].delete(:index)
        end

        it "generates correctly" do
          endpoint = schema[:endpoints][:"/api/v1/schema/employees"]
          expect(endpoint[:actions][:index][:resource])
            .to eq("Schema::EmployeeSearchResource")
        end
      end

      context "and there is a conflict" do
        it "raises error" do
          expect {
            schema
          }.to raise_error(Graphiti::Errors::ResourceEndpointConflict)
        end
      end
    end

    context "when 1 resource, multiple endpoints" do
      before do
        employee_resource.secondary_endpoint "/special_employees", [:index]
      end

      it "generates correctly" do
        expect(schema[:endpoints]).to eq({
          '/api/v1/schema/employees': {
            actions: {
              index: {resource: "Schema::EmployeeResource"},
              show: {resource: "Schema::EmployeeResource"},
              create: {resource: "Schema::EmployeeResource"},
              update: {resource: "Schema::EmployeeResource"},
              destroy: {resource: "Schema::EmployeeResource"}
            }
          },
          '/api/v1/special_employees': {
            actions: {
              index: {resource: "Schema::EmployeeResource"}
            }
          }
        })
      end
    end

    context "when context not found for endpoint" do
      let(:test_context) { nil }

      it "does not add the endpoint to the schema" do
        expect(schema[:endpoints]).to eq({})
      end
    end

    context "when context not found for a specific endpoint action" do
      around do |e|
        Graphiti.config.context_for_endpoint = ->(path, action) {
          test_context if [:show, :create].include?(action)
        }
        begin
          e.run
        ensure
          Graphiti.config.context_for_endpoint = nil
        end
      end

      it "does not add the action to the schema" do
        expect(schema[:endpoints][:'/api/v1/schema/employees'][:actions].keys)
          .to eq([:show, :create])
      end
    end

    context "when polymorphic resources" do
      let(:resources) { [PORO::CreditCardResource, PORO::VisaResource] }

      it "generates a polymorphic schema for the parent but not the children" do
        expect(schema[:resources][0][:polymorphic]).to eq(true)
        expect(schema[:resources][0][:children])
          .to eq(["PORO::VisaResource", "PORO::GoldVisaResource", "PORO::MastercardResource"])
        visa = schema[:resources].find { |r| r[:name] == "PORO::VisaResource" }
        expect(visa).to_not have_key(:polymorphic)
        expect(visa).to_not have_key(:children)
      end
    end

    context "when polymorphic relationship" do
      let(:house_resource) do
        Class.new(application_resource) do
          def self.name
            "Schema::HouseResource"
          end
        end
      end

      let(:condo_resource) do
        Class.new(application_resource) do
          def self.name
            "Schema::CondoResource"
          end
        end
      end

      before do
        house_res = house_resource
        condo_res = condo_resource
        employee_resource.class_eval do
          polymorphic_belongs_to :dwelling do
            group_by(:dwelling_type) do
              on(:House).belongs_to(:adf, resource: house_res)
              on(:Condo).belongs_to(:condo, resource: condo_res)
            end
          end
        end
      end

      it "associates the relationship with multiple resources" do
        expect(schema[:resources][0][:relationships][:dwelling]).to eq({
          description: nil,
          parent_resource: "Schema::EmployeeResource",
          type: "polymorphic_belongs_to",
          resources: ["Schema::HouseResource", "Schema::CondoResource"]
        })
      end
    end

    context "when Rails is defined" do
      let(:rails) do
        app = double(eager_load!: true, config: double.as_null_object)
        double(application: app).as_null_object
      end

      before do
        stub_const("Rails", rails)
        allow_any_instance_of(Graphiti::Sideload).to receive(:check!)
      end

      it "eager loads classes" do
        expect(rails.application).to receive(:eager_load!)
        schema
      end
    end

    context "when given a hash attribute w/schema" do
      xit "is noted as record type" do
      end
    end

    context "when enum" do
      xit "lists variants" do
      end
    end
  end

  describe ".generate!" do
    let(:new_schema) do
      {}
    end

    let(:old_schema) do
      {}.to_json
    end

    before do
      allow(FileUtils).to receive(:mkdir_p).with("/schema/path")
      allow(File).to receive(:write)
      allow(File).to receive(:read).with("/schema/path/schema.json") { old_schema }
      allow(File).to receive(:exist?)
        .with("/schema/path/schema.json") { true }
      allow(described_class).to receive(:generate) { new_schema }
      allow(Graphiti.config)
        .to receive(:schema_path) { "/schema/path/schema.json" }
    end

    it "generates new schema" do
      resources = ["a"]
      expect(described_class).to receive(:generate)
        .with(resources) { new_schema }
      described_class.generate!(resources)
    end

    context "when prior schema does not exist" do
      before do
        allow(File).to receive(:exist?)
          .with("/schema/path/schema.json") { false }
      end

      it "does not diff" do
        expect(Graphiti::SchemaDiff).to_not receive(:new)
        described_class.generate!
      end

      it "writes schema" do
        expect(File).to receive(:write)
          .with("/schema/path/schema.json", JSON.pretty_generate(new_schema))
        described_class.generate!
      end

      it "returns empty array" do
        expect(described_class.generate!).to eq([])
      end
    end

    context "when prior schema exists" do
      before do
        allow(File).to receive(:exist?)
          .with("/schema/path/schema.json") { true }
      end

      context "when no backwards-incompatibilities" do
        before do
          expect_any_instance_of(Graphiti::SchemaDiff)
            .to receive(:compare) { [] }
        end

        it "writes file" do
          expect(File).to receive(:write)
            .with("/schema/path/schema.json", JSON.pretty_generate(new_schema))
          described_class.generate!
        end

        it "returns empty array" do
          expect(described_class.generate!).to eq([])
        end
      end

      context "when backwards-incompatibilities" do
        before do
          allow_any_instance_of(Graphiti::SchemaDiff)
            .to receive(:compare) { ["some diff error"] }
        end

        it "returns the list" do
          expect_any_instance_of(Graphiti::SchemaDiff)
            .to receive(:compare) { ["some diff error"] }
          expect(described_class.generate!).to eq(["some diff error"])
        end

        it "does not write the file" do
          expect(File).to_not receive(:write)
          described_class.generate!
        end

        context "but FORCE_SCHEMA set" do
          around do |e|
            ENV["FORCE_SCHEMA"] = "true"
            e.run
          ensure
            ENV["FORCE_SCHEMA"] = nil
          end

          it "writes the file" do
            contents = JSON.pretty_generate(new_schema)
            expect(File).to receive(:write)
              .with("/schema/path/schema.json", contents)
            described_class.generate!
          end

          it "returns empty array" do
            expect(described_class.generate!).to eq([])
          end
        end
      end
    end
  end
end
