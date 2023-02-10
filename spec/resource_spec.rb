require "spec_helper"

RSpec.describe Graphiti::Resource do
  let(:klass) { Class.new(described_class) }
  let(:instance) { klass.new }

  describe "subclassing" do
    describe "an ApplicationResource" do
      let(:klass) do
        Class.new(described_class) do
          self.abstract_class = true
        end
      end

      it "sets defaults" do
        expect(klass.adapter.ancestors[0])
          .to eq(Graphiti::Adapters::Abstract)
        expect(klass.default_sort).to be_nil
        expect(klass.default_page_size).to be_nil
        expect(klass.attributes_readable_by_default).to eq(true)
        expect(klass.attributes_writable_by_default).to eq(true)
        expect(klass.attributes_sortable_by_default).to eq(true)
        expect(klass.attributes_filterable_by_default).to eq(true)
        expect(klass.attributes_schema_by_default).to eq(true)
        expect(klass.relationships_readable_by_default).to eq(true)
        expect(klass.relationships_writable_by_default).to eq(true)
        expect(klass.filters_accept_nil_by_default).to eq(false)
        expect(klass.filters_deny_empty_by_default).to eq(false)
      end

      it "does not have serializer, type, model, or graphql_entrypoint" do
        expect(klass.serializer).to be_nil
        expect(klass.type).to be_nil
        expect(klass.model).to be_nil
        expect(klass.graphql_entrypoint).to be_nil
      end

      it "adds to global list of resources" do
        expect(Graphiti.resources).to include(klass)
      end
    end

    describe "a further descendant of ApplicationResource" do
      let(:app_resource) do
        Class.new(described_class) do
          self.abstract_class = true
        end
      end

      let(:klass) do
        Class.new(app_resource)
      end

      it "infers serializer, type, and graphql_entrypoint" do
        expect(klass.serializer.ancestors[3])
          .to eq(Graphiti::Serializer)
        # This class has no name
        expect(klass.type).to eq(:undefined_jsonapi_type)
        expect(klass.graphql_entrypoint).to eq(:undefinedJsonapiTypes)
      end

      it "inherits defaults" do
        expect(klass.adapter.ancestors[0])
          .to eq(Graphiti::Adapters::Abstract)
        expect(klass.default_sort).to be_nil
        expect(klass.default_page_size).to be_nil
        expect(klass.attributes_readable_by_default).to eq(true)
        expect(klass.attributes_writable_by_default).to eq(true)
        expect(klass.attributes_sortable_by_default).to eq(true)
        expect(klass.attributes_filterable_by_default).to eq(true)
        expect(klass.attributes_schema_by_default).to eq(true)
        expect(klass.relationships_readable_by_default).to eq(true)
        expect(klass.relationships_writable_by_default).to eq(true)
        expect(klass.filters_accept_nil_by_default).to eq(false)
        expect(klass.filters_deny_empty_by_default).to eq(false)
      end

      context "when rails" do
        before do
          rails = double \
            application: double(config: double(eager_load: eager_load))
          stub_const("Rails", rails.as_null_object)
        end

        context "and eager loading" do
          let(:eager_load) { true }

          it "does NOT assign relationships to the serializer" do
            klass.has_many :positions, resource: PORO::PositionResource
            expect(klass.serializer.relationship_blocks).to be_blank
            Graphiti.setup!
            expect(klass.serializer.relationship_blocks).to_not be_blank
          end
        end

        context "and NOT eager loading" do
          let(:eager_load) { false }

          it "assigns relationships to the serializer" do
            klass.has_many :positions, resource: PORO::PositionResource
            expect(klass.serializer.relationship_blocks).to_not be_blank
          end
        end
      end

      context "when assigning new adapter" do
        let(:adapter) do
          Class.new(Graphiti::Adapters::Abstract) do
            def count(*args)
              42
            end
          end
        end

        def count
          klass.config[:stats][:total].calculations[:count].call
        end

        it "updates total count config" do
          expect { count }.to raise_error(ArgumentError)
          klass.adapter = adapter
          expect(count).to eq(42)
        end
      end

      context "when model can be inferred" do
        before do
          klass.class_eval do
            def self.name
              "PORO::EmployeeResource"
            end
          end
        end

        it "infers correctly" do
          expect(klass.model).to eq(PORO::Employee)
        end
      end

      context "when model cannot be inferred" do
        it "raises helpful error" do
          expect {
            klass.model
          }.to raise_error(Graphiti::Errors::ModelNotFound)
        end
      end

      context "when overriding defaults" do
        let(:klass) do
          Class.new(app_resource) do
            self.adapter = PORO::Adapter
            self.default_sort = [{name: :asc}]
            self.default_page_size = 4
            self.attributes_readable_by_default = false
            self.attributes_writable_by_default = false
            self.attributes_sortable_by_default = false
            self.attributes_filterable_by_default = false
            self.attributes_schema_by_default = false
            self.relationships_readable_by_default = false
            self.relationships_writable_by_default = false
            self.filters_accept_nil_by_default = true
            self.filters_deny_empty_by_default = true
          end
        end

        it "works" do
          expect(klass.adapter).to eq(PORO::Adapter)
          expect(klass.default_sort).to eq([{name: :asc}])
          expect(klass.default_page_size).to eq(4)
          expect(klass.attributes_readable_by_default).to eq(false)
          expect(klass.attributes_writable_by_default).to eq(false)
          expect(klass.attributes_sortable_by_default).to eq(false)
          expect(klass.attributes_filterable_by_default).to eq(false)
          expect(klass.attributes_schema_by_default).to eq(false)
          expect(klass.relationships_readable_by_default).to eq(false)
          expect(klass.relationships_writable_by_default).to eq(false)
          expect(klass.filters_accept_nil_by_default).to eq(true)
          expect(klass.filters_deny_empty_by_default).to eq(true)
        end
      end

      context "when manually setting serializer" do
        let(:klass) do
          Class.new(app_resource) do
            self.serializer = PORO::EmployeeSerializer
          end
        end

        it "works" do
          expect(klass.serializer.ancestors[1]).to eq(PORO::EmployeeSerializer)
        end
      end

      context "when manually setting type" do
        let(:klass) do
          Class.new(app_resource) do
            self.type = :blahs
          end
        end

        it "works" do
          expect(klass.type).to eq(:blahs)
        end
      end

      context "when manually setting type as string" do
        let(:klass) do
          Class.new(app_resource) do
            self.type = "blahs"
          end
        end

        it "works" do
          expect(klass.type).to eq(:blahs)
        end
      end
    end

    describe "a descendent of a non-abstract Resource" do
      let(:app_resource) do
        Class.new(described_class) do
          self.abstract_class = true
        end
      end

      let(:klass1) do
        Class.new(app_resource)
      end

      let(:klass2) do
        Class.new(klass1)
      end

      it "inherits type and serializer" do
        expect(klass2.type).to eq(:undefined_jsonapi_type)
        expect(klass2.serializer.ancestors[1]).to eq(klass1.serializer)
      end

      context "when overriding type" do
        let(:klass1) do
          Class.new(app_resource) do
            self.type = :employees
            self.serializer = PORO::EmployeeSerializer
          end
        end

        let(:klass2) do
          Class.new(klass1) do
            self.type = :blahs
          end
        end

        it "sets type on the subclass serializer, NOT the superclass serializer" do
          expect(PORO::EmployeeSerializer.type_val).to be_nil
          expect(klass1.serializer.type_val).to eq(:employees)
          expect(klass2.serializer.type_val).to eq(:blahs)
        end
      end

      context "when adding an attribute" do
        let(:klass1) do
          Class.new(app_resource) do
            self.type = :employees
            attribute :first_name, :string
          end
        end

        let(:klass2) do
          Class.new(klass1) do
            attribute :another, :string
          end
        end

        it "adds to the resource serializer, NOT the superclass serializer" do
          expect(klass1.serializer.attribute_blocks.keys)
            .to match_array([:first_name])
          expect(klass2.serializer.attribute_blocks.keys)
            .to match_array([:first_name, :another])
        end
      end

      context "when overriding serializer" do
        class TestResourceOverrideSerializer < PORO::ApplicationSerializer
        end

        let(:klass1) do
          Class.new(app_resource) do
            attribute :first_name, :string
          end
        end

        let(:klass2) do
          Class.new(klass1) do
            self.serializer = TestResourceOverrideSerializer
            attribute :another, :string
          end
        end

        it "applies super + subclass attributes to the serializer, without affecting superclass" do
          expect(klass1.serializer.attribute_blocks.keys)
            .to eq([:first_name])
          expect(klass2.serializer.attribute_blocks.keys)
            .to match_array([:first_name, :another])
        end
      end

      context "when the superclass overrode defaults" do
        let(:klass1) do
          Class.new(app_resource) do
            self.adapter = PORO::Adapter
            self.default_sort = [{name: :asc}]
            self.default_page_size = 4
            self.attributes_readable_by_default = false
            self.attributes_writable_by_default = false
            self.attributes_sortable_by_default = false
            self.attributes_filterable_by_default = false
            self.attributes_schema_by_default = false
            self.relationships_readable_by_default = false
            self.relationships_writable_by_default = false
            self.filters_accept_nil_by_default = true
            self.filters_deny_empty_by_default = true
          end
        end

        it "carries them over to the subclass" do
          expect(klass2.adapter).to eq(PORO::Adapter)
          expect(klass2.default_sort).to eq([{name: :asc}])
          expect(klass2.default_page_size).to eq(4)
          expect(klass2.attributes_readable_by_default).to eq(false)
          expect(klass2.attributes_writable_by_default).to eq(false)
          expect(klass2.attributes_sortable_by_default).to eq(false)
          expect(klass2.attributes_filterable_by_default).to eq(false)
          expect(klass2.attributes_schema_by_default).to eq(false)
          expect(klass2.relationships_readable_by_default).to eq(false)
          expect(klass2.relationships_writable_by_default).to eq(false)
          expect(klass2.filters_accept_nil_by_default).to eq(true)
          expect(klass2.filters_deny_empty_by_default).to eq(true)
        end
      end

      context "when sideloading" do
        let(:some_resource) do
          Class.new(Graphiti::Resource)
        end

        let(:klass1) do
          klass = Class.new(app_resource)
          klass.allow_sideload :foo, type: :has_many, resource: some_resource
          klass
        end

        let(:klass2) do
          klass = Class.new(klass1)
          klass.allow_sideload :bar, type: :belongs_to, resource: some_resource
          klass
        end

        it "inherits sideloads from the parent" do
          expect(klass2.sideloads.keys).to include(:foo)
        end

        it "can add sideloads without modifying the parent" do
          expect(klass1.sideloads.keys).to_not include(:bar)
          expect(klass2.sideloads.keys).to include(:bar)
        end

        it "adds sideloads to subclass serializer, NOT superclass serializer" do
          expect(klass1.serializer.relationship_blocks.keys).to eq([:foo])
          expect(klass2.serializer.relationship_blocks.keys)
            .to match_array([:foo, :bar])
        end
      end
    end
  end

  describe "#stat" do
    let(:avg_proc) { proc { |scope, attr| 1 } }

    before do
      klass.class_eval do
        stat :myattr do
          average { |scope, attr| 1 }
        end
      end
    end

    context "when passing strings" do
      it "returns the corresponding proc" do
        expect(instance.stat("myattr", "average").call(nil, nil)).to eq(1)
      end
    end

    context "when passing symbols" do
      it "returns the corresponding proc" do
        expect(instance.stat(:myattr, :average).call(nil, nil)).to eq(1)
      end
    end

    context "when no corresponding attribute" do
      it "raises error" do
        expect { instance.stat(:foo, "average") }
          .to raise_error(Graphiti::Errors::StatNotFound, "No stat configured for calculation 'average' on attribute :foo")
      end
    end

    context "when no corresponding calculation" do
      it "raises error" do
        expect { instance.stat("myattr", :median) }
          .to raise_error(Graphiti::Errors::StatNotFound, "No stat configured for calculation :median on attribute :myattr")
      end
    end
  end

  describe "#with_context" do
    it "sets/resets correct context" do
      dbl = double
      instance.with_context(dbl, :index) do
        expect(instance.context).to eq(dbl)
        expect(instance.context_namespace).to eq(:index)
      end
      expect(instance.context).to be_nil
      expect(instance.context_namespace).to be_nil
    end

    context "when an error" do
      around do |e|
        Graphiti.with_context("orig", "orig namespace") do
          e.run
        end
      end

      it "resets the context" do
        expect {
          instance.with_context({}, :index) do
            raise "foo"
          end
        }.to raise_error("foo")
        expect(instance.context).to eq("orig")
        expect(instance.context_namespace).to eq("orig namespace")
      end
    end
  end

  describe "#default_sort" do
    it "defaults" do
      expect(instance.default_sort).to be_nil
    end
  end

  describe "#default_page_size" do
    it "defaults" do
      expect(instance.default_page_size).to be_nil
    end
  end

  describe "#max_page_size" do
    it "defaults" do
      expect(instance.max_page_size).to eq(1_000)
    end
  end

  describe "#type" do
    it "defaults" do
      expect(instance.type).to eq(:undefined_jsonapi_type)
    end
  end

  describe "#adapter" do
    it "defaults" do
      expect(instance.adapter.class).to eq(Graphiti::Adapters::Abstract)
    end
  end

  describe ".graphql_entrypoint" do
    it "automatically converts to gql camelCase" do
      klass.graphql_entrypoint = :exemplary_employees
      expect(klass.graphql_entrypoint).to eq(:exemplaryEmployees)
    end
  end

  describe ".allow_sideload" do
    it "uses Sideload as default class" do
      sideload = klass.allow_sideload :comments, type: :has_many
      expect(sideload.class.ancestors[1]).to eq(Graphiti::Sideload)
    end

    it "assigns parent resource as self" do
      sideload = klass.allow_sideload :comments, type: :has_many
      expect(sideload.parent_resource_class).to eq(klass)
    end

    it "adds to the list of sideloads" do
      sideload = klass.allow_sideload :comments, type: :has_many
      expect(klass.sideloads[:comments]).to eq(sideload)
    end

    it "passes options to the sideload constructor" do
      sideload = klass.allow_sideload :comments, type: :foo
      expect(sideload.type).to eq(:foo)
    end

    context "when passed a block" do
      it "is processed" do
        sideload = klass.allow_sideload :comments, type: :has_many do
          scope do |parents|
            "foo"
          end
        end
        expect(sideload.class.scope_proc.call([])).to eq("foo")
      end
    end

    context "when passed explicit :class" do
      it "is used" do
        sideload = klass.allow_sideload :comments,
          class: Graphiti::Sideload::HasMany
        expect(sideload.class.ancestors[1])
          .to eq(Graphiti::Sideload::HasMany)
      end
    end
  end

  describe ".association_names" do
    it "collects nested + resource sideloads" do
      position_resource = Class.new(PORO::PositionResource) do
        belongs_to :department
        def self.name
          "PORO::PositionResource"
        end
      end
      klass.has_many :positions, resource: position_resource
      expect(klass.association_names)
        .to match_array([:positions, :department])
    end

    context "when no allowlist" do
      it "defaults to empty array" do
        expect(klass.association_names).to eq([])
      end
    end
  end

  describe ".serializer=" do
    let(:serializer) do
      Class.new(Graphiti::Serializer)
    end

    it "assigns the serializer class" do
      klass.serializer = serializer
      expect(klass.serializer.ancestors[1]).to eq(serializer)
    end

    it "assigns type to the serializer class" do
      klass.type = :things
      klass.serializer = serializer
      expect(klass.serializer.type_val).to eq(:things)
    end

    context "when attributes are already defined" do
      it "applies them to the resource serializer, NOT the superclass" do
        klass.attribute :foo, :string
        expect(serializer.attribute_blocks[:foo]).to be_blank
        klass.serializer = serializer
        expect(serializer.attribute_blocks[:foo]).to_not be_present
        expect(klass.serializer.attribute_blocks[:foo]).to be_present
      end

      context "but they are also already defined on the serializer" do
        before do
          serializer.attribute :foo do
            "predefined"
          end
          klass.attribute :foo, :string
          klass.serializer = serializer
        end

        it "does not override the serializer" do
          block = klass.serializer.attribute_blocks[:foo]
          expect(block.call(nil)).to eq("predefined")
        end
      end
    end
  end

  it "automatically adds id attribute" do
    expect(klass.attributes[:id]).to be_present
  end

  describe ".attribute" do
    def apply_attribute
      klass.attribute :foo, :string
    end

    it "adds to the list of attributes" do
      apply_attribute
      expect(klass.config[:attributes].keys).to eq([:id, :foo])
    end

    it "defaults based on configuration" do
      apply_attribute
      attribute = klass.config[:attributes][:foo]
      expect(attribute[:readable]).to eq(true)
      expect(attribute[:writable]).to eq(true)
      expect(attribute[:sortable]).to eq(true)
      expect(attribute[:filterable]).to eq(true)
      expect(attribute[:schema]).to eq(true)
    end

    context "when :only passed" do
      context "as single" do
        before do
          klass.attribute :foo, :string, only: :filterable
        end

        it "sets only the relevant flag" do
          att = klass.attributes[:foo]
          expect(att[:filterable]).to eq(true)
          expect(att[:readable]).to eq(false)
          expect(att[:sortable]).to eq(false)
          expect(att[:writable]).to eq(false)
          expect(att[:schema]).to eq(true)
        end
      end

      context "as array" do
        before do
          klass.attribute :foo, :string, only: [:filterable, :sortable]
        end

        it "sets only the relevant flag" do
          att = klass.attributes[:foo]
          expect(att[:filterable]).to eq(true)
          expect(att[:readable]).to eq(false)
          expect(att[:sortable]).to eq(true)
          expect(att[:writable]).to eq(false)
          expect(att[:schema]).to eq(true)
        end
      end

      context "and given a guard" do
        before do
          klass.attribute :foo, :string,
            only: [:filterable], filterable: :admin?
        end

        it "respects the option" do
          att = klass.attributes[:foo]
          expect(att[:filterable]).to eq(:admin?)
          expect(att[:readable]).to eq(false)
          expect(att[:sortable]).to eq(false)
          expect(att[:writable]).to eq(false)
          expect(att[:schema]).to eq(true)
        end
      end
    end

    context "when :except passed" do
      context "as single" do
        before do
          klass.attribute :foo, :string, except: :writable
        end

        it "sets only the relevant flags" do
          att = klass.attributes[:foo]
          expect(att[:filterable]).to eq(true)
          expect(att[:readable]).to eq(true)
          expect(att[:sortable]).to eq(true)
          expect(att[:writable]).to eq(false)
          expect(att[:schema]).to eq(true)
        end
      end

      context "as array" do
        before do
          klass.attribute :foo, :string, except: [:writable, :sortable]
        end

        it "sets only the relevant flags" do
          att = klass.attributes[:foo]
          expect(att[:filterable]).to eq(true)
          expect(att[:readable]).to eq(true)
          expect(att[:sortable]).to eq(false)
          expect(att[:writable]).to eq(false)
          expect(att[:schema]).to eq(true)
        end
      end
    end

    context "and given a guard" do
      before do
        klass.attribute :foo, :string, except: [:writable], sortable: :admin?
      end

      it "respects the option" do
        att = klass.attributes[:foo]
        expect(att[:filterable]).to eq(true)
        expect(att[:readable]).to eq(true)
        expect(att[:sortable]).to eq(:admin?)
        expect(att[:writable]).to eq(false)
        expect(att[:schema]).to eq(true)
      end
    end

    context "when attribute is :id" do
      before do
        klass.attribute :id, :string
      end

      it "is not added to serializer attributes" do
        expect(klass.serializer.attribute_blocks.keys).to_not include(:id)
      end

      context "and a block is passed" do
        before do
          klass.attribute :id, :string do
            "custom id"
          end
        end

        it "configures the serializer" do
          expect(klass.serializer.id_block.call).to eq("custom id")
        end
      end
    end

    context "when filterable" do
      it "adds to filter list" do
        klass.attribute :foo, :string
        expect(klass.filters[:foo]).to be_present
      end

      # Either you have different block-logic or changing type
      # Either way, should override
      context "when filter override already defined" do
        before do
          klass.attribute :foo, :string
          klass.filter :foo do
            "asdf"
          end
        end

        it "still overrides" do
          expect {
            klass.attribute :foo, :integer
          }.to(change { klass.filters[:foo] })
        end
      end

      context 'when the attribute is of type "enum"' do
        context "and an allow list is passed in" do
          it "correctly adds to the filter allowlist" do
            klass.attribute :foo, :string_enum, allow: ["bar", "baz"]
            expect(klass.filters[:foo][:allow]).to eq ["bar", "baz"]
          end
        end

        context "and an allow list omitted" do
          it "raises a helpful error" do
            expect {
              klass.attribute :foo, :string_enum
            }.to raise_error(Graphiti::Errors::MissingEnumAllowList, /string_enum/)
          end
        end
      end
    end

    context "when not filterable" do
      before do
        klass.attribute :foo, :string, filterable: false
      end

      it "does not add to filter list" do
        expect(klass.filters).to_not have_key(:foo)
      end
    end

    # raise error if filtering and attr undefined

    context "when configuration is custom" do
      before do
        klass.class_eval do
          self.attributes_readable_by_default = false
          self.attributes_writable_by_default = false
          self.attributes_sortable_by_default = false
          self.attributes_filterable_by_default = false
          self.attributes_schema_by_default = false
        end
      end

      it "respects the overrides" do
        apply_attribute
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:readable]).to eq(false)
        expect(attribute[:writable]).to eq(false)
        expect(attribute[:sortable]).to eq(false)
        expect(attribute[:filterable]).to eq(false)
        expect(attribute[:schema]).to eq(false)
      end
    end

    context "when type is not known" do
      before do
        klass.class_eval do
          def self.name
            "FooResource"
          end
        end
      end

      it "raises helpful error" do
        expect {
          klass.class_eval do
            attribute :foo, :asdf
          end
        }.to raise_error(Graphiti::Errors::TypeNotFound)
      end
    end

    context "when explicit readable flag" do
      before do
        klass.attribute :foo, :string, readable: false
      end

      it "overrides the default" do
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:readable]).to eq(false)
      end
    end

    context "when explicit writeable flag" do
      before do
        klass.attribute :foo, :string, writable: false
      end

      it "overrides the default" do
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:writable]).to eq(false)
      end
    end

    context "when explicit sortable flag" do
      before do
        klass.attribute :foo, :string, sortable: false
      end

      it "overrides the default" do
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:sortable]).to eq(false)
      end
    end

    context "when explicit filterable flag" do
      before do
        klass.attribute :foo, :string, filterable: false
      end

      it "overrides the default" do
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:filterable]).to eq(false)
      end
    end

    context "when explicit schema flag" do
      before do
        klass.attribute :foo, :string, schema: false
      end

      it "overrides the default" do
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:schema]).to eq(false)
      end
    end

    context "when readable" do
      let(:serializer) do
        Class.new(Graphiti::Serializer)
      end

      before do
        klass.serializer = serializer
      end

      it "adds the attribute to the serializer" do
        klass.attribute :foo, :string
        expect(klass.serializer.attribute_blocks.keys).to include(:foo)
      end

      context "when the serializer already defined the attribute" do
        before do
          serializer.attribute :foo do
            "predefined"
          end
          klass.serializer = serializer
        end

        it "does not override" do
          klass.attribute :foo, :string
          block = klass.serializer.attribute_blocks[:foo]
          expect(block.call(nil)).to eq("predefined")
        end
      end
    end

    context "when not readable" do
      it "does not add the attribute to the serializer" do
        klass.attribute :foo, :string, readable: false
        expect(klass.serializer.attribute_blocks[:foo]).to be_nil
      end
    end
  end

  describe ".extra_attribute" do
    it "adds to the list of extra attributes" do
      klass.extra_attribute :foo, :string
      expect(klass.config[:extra_attributes].keys).to eq([:foo])
    end

    context "when passing a block" do
      before do
        klass.extra_attribute :foo, :string do
          "custom"
        end
      end

      it "is used in serialization" do
        serialized = klass.serializer.attribute_blocks[:foo].call
        expect(serialized).to eq("custom")
      end
    end

    context "when not passing a block" do
      it "is still added to the serializer" do
        klass.extra_attribute :foo, :string
        expect(klass.serializer.attribute_blocks[:foo]).to be_present
      end

      context "and the serializer has a block" do
        before do
          klass.serializer.class_eval do
            extra_attribute :foo do
              "serializer custom"
            end
          end
          klass.extra_attribute :foo, :string
        end

        it "uses the serializer block" do
          expect(klass.serializer.attribute_blocks[:foo].call)
            .to eq("serializer custom")
        end
      end
    end
  end

  describe ".endpoint" do
    let(:klass) do
      Class.new(Graphiti::Resource) do
        def self.name
          "EmployeeResource"
        end
      end
    end

    it "infers from name" do
      expect(klass.endpoint).to eq({
        path: :'/employees',
        full_path: :'/employees',
        url: :'/employees',
        actions: [:index, :show, :create, :update, :destroy]
      })
    end

    context "when resource has base url" do
      before do
        klass.base_url = "http://example.com"
      end

      it "is applied to url" do
        expect(klass.endpoint[:url]).to eq(:'http://example.com/employees')
      end

      it "is NOT applied to full_path" do
        expect(klass.endpoint[:full_path]).to eq(:'/employees')
      end
    end

    context "when resource has endpoint namespace" do
      before do
        klass.endpoint_namespace = "/api/v1"
      end

      it "is applied to full_path" do
        expect(klass.endpoint[:full_path]).to eq(:'/api/v1/employees')
      end

      it "is applied to url" do
        expect(klass.endpoint[:url]).to eq(:'/api/v1/employees')
      end
    end

    context "when resource is namespaced" do
      let(:klass) do
        Class.new(Graphiti::Resource) do
          def self.name
            "PORO::EmployeeResource"
          end
        end
      end

      it "adds to path" do
        expect(klass.endpoint).to eq({
          path: :'/poro/employees',
          full_path: :'/poro/employees',
          url: :'/poro/employees',
          actions: [:index, :show, :create, :update, :destroy]
        })
      end
    end
  end

  describe "#endpoint" do
    let(:klass) do
      Class.new(Graphiti::Resource) do
        def self.name
          "EmployeeResource"
        end
      end
    end

    it "infers path from name" do
      expect(instance.endpoint[:path]).to eq(:'/employees')
    end

    it "defaults actions" do
      expect(instance.endpoint[:actions]).to eq([
        :index, :show, :create, :update, :destroy
      ])
    end

    context "when resource is namespaced" do
      let(:klass) do
        Class.new(Graphiti::Resource) do
          def self.name
            "PORO::EmployeeResource"
          end
        end
      end

      it "infers path from module + name" do
        expect(instance.endpoint[:path]).to eq(:'/poro/employees')
      end
    end
  end

  describe ".endpoints" do
    let(:klass) do
      Class.new(Graphiti::Resource) do
        def self.name
          "EmployeeResource"
        end
      end
    end

    it "lists primary and secondary endpoints" do
      klass.secondary_endpoint "/special_employees", [:index, :create]
      expect(klass.endpoints.length).to eq(2)
      expect(klass.endpoints[0]).to eq({
        path: :"/employees",
        full_path: :"/employees",
        url: :"/employees",
        actions: [:index, :show, :create, :update, :destroy]
      })
      expect(klass.endpoints[1]).to eq({
        path: :"/special_employees",
        full_path: :"/special_employees",
        url: :"/special_employees",
        actions: [:index, :create]
      })
    end

    context "when no endpoints" do
      before do
        klass.endpoint = nil
      end

      it "still works" do
        expect(klass.endpoints).to eq([])
      end
    end
  end

  describe "#base_scope" do
    let(:adapter) do
      Class.new(Graphiti::Adapters::Null) do
        def base_scope(model)
          "foo"
        end
      end
    end

    before do
      klass.model = PORO::Employee
      klass.adapter = adapter
    end

    it "delegates to the adapter" do
      expect(instance.base_scope).to eq("foo")
    end

    context "when overridden" do
      before do
        klass.class_eval do
          def base_scope
            "bar"
          end
        end
      end

      it "is used" do
        expect(instance.base_scope).to eq("bar")
      end
    end
  end

  describe "query methods" do
    before do
      klass.class_eval do
        self.adapter = PORO::Adapter
        self.model = PORO::Employee

        stat total: [:count]

        def base_scope
          {type: :employees}
        end
      end
    end

    let!(:employee1) { PORO::Employee.create(first_name: "Foo") }
    let!(:employee2) { PORO::Employee.create(first_name: "Bar") }
    let!(:employee3) { PORO::Employee.create(first_name: "Baz") }

    describe ".all" do
      it "executes the request correctly, returning proxy" do
        employees = klass.all(filter: {id: employee2.id})
        expect(employees).to be_a(Graphiti::ResourceProxy)
        expect(employees.map(&:id)).to eq([employee2.id])
      end

      describe "when no arguments are provided" do
        subject { klass.all.map(&:id) }
        it { is_expected.to contain_exactly(employee1.id, employee2.id, employee3.id) }
      end

      context "when running within a request context" do
        before do
          klass.class_eval do
            def self.name
              "QueryAllSpec::EmployeeResource"
            end
          end
        end

        let(:path) { "/api/v1/employees" }

        let(:request) do
          double(env: {
            "PATH_INFO" => path,
            "REQUEST_METHOD" => "GET"
          })
        end

        let(:ctx) { double(request: request) }

        context "and the request matches the primary endpoint" do
          before do
            klass.primary_endpoint "/api/v1/employees", [:index, :show]
          end

          it "works" do
            Graphiti.with_context ctx, :index do
              expect { klass.all }.to_not raise_error
            end
          end

          it "can sideload" do
            klass.has_many :positions, resource: PORO::PositionResource
            Graphiti.with_context ctx, :index do
              expect { klass.all(include: "positions") }
                .to_not raise_error
            end
          end

          context "with an explicit mime type" do
            let!(:path) { "/api/v1/employees.json" }

            it "still works" do
              Graphiti.with_context ctx, :index do
                expect { klass.all }.to_not raise_error
              end
            end
          end

          context "that is a show route with an id" do
            before do
              request.env["PATH_INFO"] += "/123"
            end

            it "works" do
              Graphiti.with_context ctx, :show do
                expect { klass.find(id: 123) }.to_not raise_error
              end
            end
          end

          # singular resources
          context "that is a show route without an id" do
            before do
              request.env["PATH_INFO"] += ""
            end

            it "works" do
              Graphiti.with_context ctx, :show do
                expect { klass.find }.to_not raise_error
              end
            end
          end

          # singular resource with singular route
          context "that is a singular show route without an id but finding the resource by id" do
            before do
              request.env["PATH_INFO"] += ""
            end

            it "works" do
              Graphiti.with_context ctx, :show do
                expect { klass.find(id: 123) }.to_not raise_error
              end
            end
          end
        end

        context "and the request matches a secondary endpoint" do
          before do
            klass.secondary_endpoint "/api/v1/employees"
          end

          it "works" do
            Graphiti.with_context ctx, :index do
              expect { klass.all }.to_not raise_error
            end
          end
        end

        context "and the path matches an endpoint, but not an action" do
          before do
            klass.primary_endpoint "/api/v1/employees", [:create]
          end

          it "raises error" do
            Graphiti.with_context ctx, :index do
              expect {
                klass.all
              }.to raise_error(Graphiti::Errors::InvalidEndpoint, /QueryAllSpec::EmployeeResource cannot be called directly from endpoint \/api\/v1\/employees/)
            end
          end

          context "but the action list is modified" do
            before do
              klass.class_eval do
                endpoint[:actions] << :index
              end
            end

            it "works" do
              Graphiti.with_context ctx, :index do
                expect {
                  klass.all
                }.to_not raise_error
              end
            end
          end

          context "but .allow_request? is overridden" do
            before do
              klass.class_eval do
                def self.allow_request?(path, params, action)
                  true
                end
              end
            end

            it "works" do
              Graphiti.with_context ctx, :index do
                expect {
                  klass.all
                }.to_not raise_error
              end
            end
          end
        end

        context "and the path does not match an endpoint" do
          it "raises error" do
            Graphiti.with_context ctx, :index do
              expect {
                klass.all
              }.to raise_error(Graphiti::Errors::InvalidEndpoint, /QueryAllSpec::EmployeeResource cannot be called directly from endpoint \/api\/v1\/employees/)
            end
          end

          context "but endpoint checks are turned off" do
            around do |e|
              orig = klass.validate_endpoints
              begin
                klass.validate_endpoints = false
                e.run
              ensure
                klass.validate_endpoints = orig
              end
            end

            it "allows the request" do
              Graphiti.with_context ctx, :index do
                expect {
                  klass.all
                }.to_not raise_error
              end
            end
          end
        end
      end

      context "when stats" do
        it "returns correct hash" do
          proxy = klass.all(stats: {total: "count"})
          expect(proxy.stats).to eq({
            total: {count: "poro_count_total"}
          })
        end
      end

      context "when no stats" do
        it "returns empty hash" do
          proxy = klass.all({})
          expect(proxy.stats).to eq({})
        end
      end

      context "when passed a base scope" do
        it "uses the scope" do
          base = {type: :employees, conditions: {id: employee3.id}}
          employees, _ = klass.all({}, base)
          expect(employees.map(&:id)).to eq([employee3.id])
        end
      end
    end

    describe ".find" do
      before do
        klass.class_eval do
          def self.name
            "QueryFindSpec::EmployeeResource"
          end
        end
      end

      it "takes the id param and applies as a filter, returning single record" do
        proxy = klass.find(id: employee2.id)
        expect(proxy.data.id).to eq(employee2.id)
      end

      it "supports other params as well" do
        klass.class_eval do
          attr_accessor :got_foo
          extra_attribute(:foo, :string)
          def around_scoping(scope, query_hash)
            yield scope
            if query_hash[:extra_fields][:employees] == [:foo]
              scope[:conditions][:id] = 3
            end
            scope
          end
        end

        employees = klass.find({
          id: employee2.id,
          extra_fields: {employees: "foo"}
        })
        expect(employees.data.id).to eq(3)
      end

      context "when running in request context" do
        let(:request) do
          double(env: {
            "PATH_INFO" => "/api/v1/employees/#{employee2.id}",
            "REQUEST_METHOD" => "GET"
          })
        end

        let(:ctx) { double(request: request) }

        context "and the path is not supported" do
          it "raises error" do
            Graphiti.with_context ctx, :show do
              expect {
                klass.find({id: employee2.id})
              }.to raise_error(Graphiti::Errors::InvalidEndpoint, /QueryFindSpec::EmployeeResource cannot be called directly from endpoint \/api\/v1\/employees/)
            end
          end
        end

        context "and the path is supported" do
          before do
            klass.primary_endpoint "/api/v1/employees"
          end

          it "works" do
            Graphiti.with_context ctx, :show do
              expect {
                klass.find({id: employee2.id})
              }.to_not raise_error
            end
          end
        end
      end

      context "when stats" do
        it "returns correct hash" do
          proxy = klass.find({
            id: employee2.id,
            stats: {total: "count"}
          })
          expect(proxy.stats).to eq(total: {count: "poro_count_total"})
        end
      end

      context "when no stats" do
        it "returns empty hash" do
          proxy = klass.find(id: employee2.id)
          expect(proxy.stats).to eq({})
        end
      end

      context "when no record found" do
        it "raises helpful error" do
          expect {
            klass.find(id: 9999).data
          }.to raise_error(Graphiti::Errors::RecordNotFound)
        end
      end

      context "when passed a base scope" do
        before do
          expect(PORO::DB).to receive(:all).with({
            conditions: {first_name: "adsf", id: [1]},
            page: 1,
            per: 20
          }).and_call_original
        end

        it "is used" do
          expect {
            klass.find({id: employee1.id}, {
              conditions: {first_name: "adsf"}
            }).data
          }.to raise_error(Graphiti::Errors::RecordNotFound)
        end
      end
    end
  end

  describe ".build" do
    before do
      klass.class_eval do
        def self.name
          "ResourceBuildSpec::EmployeeResource"
        end
      end
    end

    context "when running in request context" do
      let(:request) do
        double(env: {
          "PATH_INFO" => "/api/v1/employees",
          "REQUEST_METHOD" => "GET"
        })
      end

      let(:ctx) { double(request: request) }

      context "and the path is not supported" do
        it "raises error" do
          Graphiti.with_context ctx, :create do
            expect {
              klass.build({})
            }.to raise_error(Graphiti::Errors::InvalidEndpoint, /ResourceBuildSpec::EmployeeResource cannot be called directly from endpoint \/api\/v1\/employees/)
          end
        end
      end

      context "and the path is supported" do
        before do
          klass.class_eval do
            self.adapter = PORO::Adapter
            primary_endpoint "/api/v1/employees"
            self.model = PORO::Employee
            def base_scope
              {}
            end
          end
        end

        it "works" do
          Graphiti.with_context ctx, :create do
            expect {
              klass.build({})
            }.to_not raise_error
          end
        end
      end
    end
  end

  describe "get_attr" do
    it "returns the relevant attribute" do
      klass.attribute :foo, :string
      expect(instance.get_attr(:foo, :sortable))
        .to eq(klass.attributes[:foo])
    end

    context "when the attribute is not found" do
      it "returns false" do
        expect(instance.get_attr(:foo, :sortable)).to eq(false)
      end
    end

    context "when the attribute does not support the flag" do
      before do
        klass.attribute :foo, :string, sortable: false
      end

      it "returns false" do
        expect(instance.get_attr(:foo, :sortable)).to eq(false)
      end
    end

    context "when the attribute does not pass the guard" do
      before do
        klass.class_eval do
          attribute :foo, :string, sortable: :admin?
          def admin?
            false
          end
        end
      end

      it "returns false" do
        expect(instance.get_attr(:foo, :sortable, request: true)).to eq(false)
      end
    end
  end

  describe "get_attr!" do
    it "returns the relevant attribute" do
      klass.attribute :foo, :string
      expect(instance.get_attr!(:foo, :sortable))
        .to eq(klass.attributes[:foo])
    end

    context "when the attribute is not found" do
      it "raises helpful error" do
        expect {
          instance.get_attr!(:foo, :sortable)
        }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to add sort attribute :foo, but could not find an attribute with that name.")
      end
    end

    context "when the attribute does not support the flag" do
      before do
        klass.attribute :foo, :string, sortable: false
      end

      it "raises helpful error" do
        expect {
          instance.get_attr!(:foo, :sortable)
        }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to add sort attribute :foo, but the attribute was marked :sortable => false.")
      end
    end

    context "when not running in a request context" do
      before do
        klass.attribute :foo, :string, sortable: :admin?
      end

      it "does not check the guard" do
        expect_any_instance_of(klass).to_not receive(:admin?)
        instance.get_attr!(:foo, :sortable)
      end
    end

    context "when the attribute does not pass the guard" do
      before do
        klass.class_eval do
          attribute :foo, :string, sortable: :admin?
          def admin?
            false
          end
        end
      end

      it "raises helpful error" do
        expect {
          instance.get_attr!(:foo, :sortable, request: true)
        }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to sort on attribute :foo, but the guard :admin? did not pass.")
      end
    end

    context "when the attribute is required" do
      before do
        klass.attribute :foo, :string, filterable: :required
      end

      it "returns the attribute" do
        att = instance.get_attr!(:foo, :sortable, request: true)
        expect(att).to eq(klass.attributes[:foo])
      end
    end
  end

  describe "#typecast" do
    subject(:typecast) { instance.typecast(:foo, value, flag) }
    let(:value) { "1" }

    before do
      klass.attribute :foo, :integer
    end

    context "when readable" do
      let(:flag) { :readable }

      context "and the attribute exists" do
        it "works" do
          expect(Graphiti::Types[:integer])
            .to receive(:[]).with(:read).and_call_original
          expect(typecast).to eq(1)
        end

        context "but it is nil" do
          let(:value) { nil }

          it "does not go through coercion" do
            expect(Graphiti::Types[:integer])
              .to_not receive(:[]).with(:read)
            expect(typecast).to be_nil
          end
        end

        context "when coercion fails" do
          let(:value) { {} }

          it "raises helpful error" do
            expect {
              typecast
            }.to raise_error(Graphiti::Errors::TypecastFailed)
          end
        end

        context "but it is not readable" do
          before do
            klass.attributes[:foo][:readable] = false
          end

          it "raises helpful error" do
            expect {
              typecast
            }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to read attribute :foo, but the attribute was marked :readable => false.")
          end
        end
      end

      context "and the attribute does not exist" do
        before do
          klass.attributes.delete(:foo)
        end

        it "raises helpful error" do
          expect {
            typecast
          }.to raise_error(Graphiti::Errors::AttributeError, "AnonymousResourceClass: Tried to read attribute :foo, but could not find an attribute with that name.")
        end
      end
    end

    context "when writable" do
      let(:flag) { :writable }

      it "works" do
        expect(Graphiti::Types[:integer])
          .to receive(:[]).with(:write).and_call_original
        expect(typecast).to eq(1)
      end

      context "when coercion fails" do
        let(:value) { {} }

        it "raises helpful error" do
          expect {
            typecast
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context "when sortable" do
      let(:flag) { :sortable }

      it "works" do
        expect(Graphiti::Types[:integer])
          .to receive(:[]).with(:params).and_call_original
        expect(typecast).to eq(1)
      end

      context "when coercion fails" do
        let(:value) { {} }

        it "raises helpful error" do
          expect {
            typecast
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end

    context "when filterable" do
      let(:flag) { :filterable }

      it "works" do
        expect(Graphiti::Types[:integer])
          .to receive(:[]).with(:params).and_call_original
        expect(typecast).to eq(1)
      end

      context "and filter overrides type" do
        before do
          klass.filter :foo, :string
        end

        it "uses the filter type" do
          expect(Graphiti::Types[:string])
            .to receive(:[]).with(:params).and_call_original
          expect(typecast).to eq("1")
        end
      end

      context "when coercion fails" do
        let(:value) { {} }

        it "raises helpful error" do
          expect {
            typecast
          }.to raise_error(Graphiti::Errors::TypecastFailed)
        end
      end
    end
  end

  describe "#around_scoping" do
    before do
      klass.class_eval do
        self.adapter = Graphiti::Adapters::Null
        attr_accessor :scope

        attribute :foo, :string
        default_filter :foo do |scope, ctx|
          ctx.middle = scope.dup
          scope[:default] = true
          scope
        end

        def around_scoping(scope, query_hash)
          context.before = scope.dup
          scope = scope.merge(before: true)
          yield scope
          context.after = scope.dup
          scope.merge(after: true)
        end

        def resolve(scope)
          @scope = scope
          []
        end
      end
    end

    it "modifies scope" do
      ctx = OpenStruct.new
      Graphiti.with_context(ctx) do
        runner = Graphiti::Runner.new(klass, {})
        proxy = runner.proxy(start: true)
        expect(ctx.before).to eq(start: true)
        expect(ctx.middle).to eq(start: true, before: true)
        expect(ctx.after).to eq(start: true, before: true, default: true)
        expect(proxy.scope.object)
          .to eq(start: true, before: true, default: true, after: true)
      end
    end
  end

  describe "#resolve" do
    it "delegates to the adapter" do
      scope = double
      expect(instance.adapter).to receive(:resolve).with(scope)
      instance.resolve(scope)
    end
  end
end
