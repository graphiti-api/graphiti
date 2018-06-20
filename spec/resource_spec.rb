require 'spec_helper'

RSpec.describe JsonapiCompliable::Resource do
  let(:klass) { Class.new(described_class) }
  let(:instance) { klass.new }

  describe 'subclassing' do
    describe 'an ApplicationResource' do
      let(:klass) do
        Class.new(described_class) do
          self.abstract_class = true
        end
      end

      it 'sets defaults' do
        expect(klass.adapter.class.ancestors[0])
          .to eq(JsonapiCompliable::Adapters::Abstract)
        expect(klass.default_sort).to eq([])
        expect(klass.default_page_size).to eq(20)
        expect(klass.attributes_readable_by_default).to eq(true)
        expect(klass.attributes_writable_by_default).to eq(true)
        expect(klass.attributes_sortable_by_default).to eq(true)
        expect(klass.attributes_filterable_by_default).to eq(true)
        expect(klass.relationships_readable_by_default).to eq(true)
        expect(klass.relationships_writable_by_default).to eq(true)
      end

      it 'does not have serializer, type, or model' do
        expect(klass.serializer).to be_nil
        expect(klass.type).to be_nil
        expect(klass.model).to be_nil
      end
    end

    describe 'a further descendant of ApplicationResource' do
      let(:app_resource) do
        Class.new(described_class) do
          self.abstract_class = true
        end
      end

      let(:klass) do
        Class.new(app_resource)
      end

      it 'infers serializer and type' do
        expect(klass.serializer.ancestors[3])
          .to eq(JSONAPI::Serializable::Resource)
        # This class has no name
        expect(klass.type).to eq(:undefined_jsonapi_type)
      end

      it 'inherits defaults' do
        expect(klass.adapter.class.ancestors[0])
          .to eq(JsonapiCompliable::Adapters::Abstract)
        expect(klass.default_sort).to eq([])
        expect(klass.default_page_size).to eq(20)
        expect(klass.attributes_readable_by_default).to eq(true)
        expect(klass.attributes_writable_by_default).to eq(true)
        expect(klass.attributes_sortable_by_default).to eq(true)
        expect(klass.attributes_filterable_by_default).to eq(true)
        expect(klass.relationships_readable_by_default).to eq(true)
        expect(klass.relationships_writable_by_default).to eq(true)
      end

      context 'when model can be inferred' do
        before do
          klass.class_eval do
            def self.name
              'PORO::EmployeeResource'
            end
          end
        end

        it 'infers correctly' do
          expect(klass.model).to eq(PORO::Employee)
        end
      end

      context 'when model cannot be inferred' do
        it 'raises helpful error' do
          expect {
            klass.model
          }.to raise_error(JsonapiCompliable::Errors::ModelNotFound)
        end
      end

      context 'when overriding defaults' do
        let(:klass) do
          Class.new(app_resource) do
            self.adapter = PORO::Adapter.new
            self.default_sort = [{ name: :asc }]
            self.default_page_size = 4
            self.attributes_readable_by_default = false
            self.attributes_writable_by_default = false
            self.attributes_sortable_by_default = false
            self.attributes_filterable_by_default = false
            self.relationships_readable_by_default = false
            self.relationships_writable_by_default = false
          end
        end

        it 'works' do
          expect(klass.adapter.class).to eq(PORO::Adapter)
          expect(klass.default_sort).to eq([{ name: :asc }])
          expect(klass.default_page_size).to eq(4)
          expect(klass.attributes_readable_by_default).to eq(false)
          expect(klass.attributes_writable_by_default).to eq(false)
          expect(klass.attributes_sortable_by_default).to eq(false)
          expect(klass.attributes_filterable_by_default).to eq(false)
          expect(klass.relationships_readable_by_default).to eq(false)
          expect(klass.relationships_writable_by_default).to eq(false)
        end
      end

      context 'when manually setting serializer' do
        let(:klass) do
          Class.new(app_resource) do
            self.serializer = PORO::EmployeeSerializer
          end
        end

        it 'works' do
          expect(klass.serializer.ancestors[1]).to eq(PORO::EmployeeSerializer)
        end
      end

      context 'when manually setting type' do
        let(:klass) do
          Class.new(app_resource) do
            self.type = :blahs
          end
        end

        it 'works' do
          expect(klass.type).to eq(:blahs)
        end
      end
    end

    describe 'a descendent of a non-abstract Resource' do
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

      it 'inherits type and serializer' do
        expect(klass2.type).to eq(:undefined_jsonapi_type)
        expect(klass2.serializer.ancestors[1]).to eq(klass1.serializer)
      end

      context 'when overriding type' do
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

        it 'sets type on the subclass serializer, NOT the superclass serializer' do
          expect(PORO::EmployeeSerializer.type_val).to be_nil
          expect(klass1.serializer.type_val).to eq(:employees)
          expect(klass2.serializer.type_val).to eq(:blahs)
        end
      end

      context 'when adding an attribute' do
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

        it 'adds to the resource serializer, NOT the superclass serializer' do
          expect(klass1.serializer.attribute_blocks.keys)
            .to match_array([:first_name])
          expect(klass2.serializer.attribute_blocks.keys)
            .to match_array([:first_name, :another])
        end
      end

      context 'when overriding serializer' do
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

        it 'applies super + subclass attributes to the serializer, without affecting superclass' do
          expect(klass1.serializer.attribute_blocks.keys)
            .to eq([:first_name])
          expect(klass2.serializer.attribute_blocks.keys)
            .to match_array([:first_name, :another])
        end
      end

      context 'when the superclass overrode defaults' do
        let(:klass1) do
          Class.new(app_resource) do
            self.adapter = PORO::Adapter.new
            self.default_sort = [{ name: :asc }]
            self.default_page_size = 4
            self.attributes_readable_by_default = false
            self.attributes_writable_by_default = false
            self.attributes_sortable_by_default = false
            self.attributes_filterable_by_default = false
            self.relationships_readable_by_default = false
            self.relationships_writable_by_default = false
          end
        end

        it 'carries them over to the subclass' do
          expect(klass2.adapter.class).to eq(PORO::Adapter)
          expect(klass2.default_sort).to eq([{ name: :asc }])
          expect(klass2.default_page_size).to eq(4)
          expect(klass2.attributes_readable_by_default).to eq(false)
          expect(klass2.attributes_writable_by_default).to eq(false)
          expect(klass2.attributes_sortable_by_default).to eq(false)
          expect(klass2.attributes_filterable_by_default).to eq(false)
          expect(klass2.relationships_readable_by_default).to eq(false)
          expect(klass2.relationships_writable_by_default).to eq(false)
        end
      end

      context 'when sideloading' do
        let(:klass1) do
          Class.new(app_resource) do
            allow_sideload :foo
          end
        end

        let(:klass2) do
          Class.new(klass1) do
            allow_sideload :bar
          end
        end

        it 'inherits sideloads from the parent' do
          expect(klass2.sideloads.keys).to include(:foo)
        end

        it 'can add sideloads without modifying the parent' do
          expect(klass1.sideloads.keys).to_not include(:bar)
          expect(klass2.sideloads.keys).to include(:bar)
        end

        it 'adds sideloads to subclass serializer, NOT superclass serializer' do
          expect(klass1.serializer.relationship_blocks.keys).to eq([:foo])
          expect(klass2.serializer.relationship_blocks.keys)
            .to match_array([:foo, :bar])
        end
      end
    end
  end

  describe '#stat' do
    let(:avg_proc) { proc { |scope, attr| 1 } }

    before do
      klass.class_eval do
        allow_stat :myattr do
          average { |scope, attr| 1 }
        end
      end
    end

    context 'when passing strings' do
      it 'returns the corresponding proc' do
        expect(instance.stat('myattr', 'average').call(nil, nil)).to eq(1)
      end
    end

    context 'when passing symbols' do
      it 'returns the corresponding proc' do
        expect(instance.stat(:myattr, :average).call(nil, nil)).to eq(1)
      end
    end

    context 'when no corresponding attribute' do
      it 'raises error' do
        expect { instance.stat(:foo, 'average') }
          .to raise_error(JsonapiCompliable::Errors::StatNotFound, "No stat configured for calculation 'average' on attribute :foo")
      end
    end

    context 'when no corresponding calculation' do
      it 'raises error' do
        expect { instance.stat('myattr', :median) }
          .to raise_error(JsonapiCompliable::Errors::StatNotFound, "No stat configured for calculation :median on attribute :myattr")
      end
    end
  end

  describe '#with_context' do
    it 'sets/resets correct context' do
      dbl = double
      instance.with_context(dbl, :index) do
        expect(instance.context).to eq(dbl)
        expect(instance.context_namespace).to eq(:index)
      end
      expect(instance.context).to be_nil
      expect(instance.context_namespace).to be_nil
    end

    context 'when an error' do
      around do |e|
        JsonapiCompliable.with_context('orig', 'orig namespace') do
          e.run
        end
      end

      it 'resets the context' do
        expect {
          instance.with_context({}, :index) do
            raise 'foo'
          end
        }.to raise_error('foo')
        expect(instance.context).to eq('orig')
        expect(instance.context_namespace).to eq('orig namespace')
      end
    end
  end

  describe '#default_sort' do
    it 'defaults' do
      expect(instance.default_sort).to eq([])
    end
  end

  describe '#default_page_size' do
    it 'defaults' do
      expect(instance.default_page_size).to eq(20)
    end
  end

  describe '#type' do
    it 'defaults' do
      expect(instance.type).to eq(:undefined_jsonapi_type)
    end
  end

  describe '#adapter' do
    it 'defaults' do
      expect(instance.adapter.class).to eq(JsonapiCompliable::Adapters::Abstract)
    end
  end

  describe '.allow_sideload' do
    it 'uses Sideload as default class' do
      sideload = klass.allow_sideload :comments
      expect(sideload.class.ancestors[1]).to eq(JsonapiCompliable::Sideload)
    end

    it 'assigns parent resource as self' do
      sideload = klass.allow_sideload :comments
      expect(sideload.parent_resource_class).to eq(klass)
    end

    it 'adds to the list of sideloads' do
      sideload = klass.allow_sideload :comments
      expect(klass.sideloads[:comments]).to eq(sideload)
    end

    it 'passes options to the sideload constructor' do
      sideload = klass.allow_sideload :comments, type: :foo
      expect(sideload.type).to eq(:foo)
    end

    context 'when passed a block' do
      it 'is processed' do
        sideload = klass.allow_sideload :comments do
          scope do |parents|
            'foo'
          end
        end
        expect(sideload.class.scope_proc.call([])).to eq('foo')
      end
    end

    context 'when passed explicit :class' do
      it 'is used' do
        sideload = klass.allow_sideload :comments,
          class: JsonapiCompliable::Sideload::HasMany
        expect(sideload.class.ancestors[1])
          .to eq(JsonapiCompliable::Sideload::HasMany)
      end
    end
  end

  describe '.association_names' do
    it 'collects nested + resource sideloads' do
      position_resource = Class.new(PORO::PositionResource) do
        belongs_to :department
        def self.name
          'PORO::PositionResource'
        end
      end
      klass.has_many :positions, resource: position_resource
      expect(klass.association_names)
        .to match_array([:positions, :department])
    end

    context 'when no whitelist' do
      it 'defaults to empty array' do
        expect(klass.association_names).to eq([])
      end
    end
  end

  describe '.serializer=' do
    let(:serializer) do
      Class.new(JSONAPI::Serializable::Resource)
    end

    it 'assigns the serializer class' do
      klass.serializer = serializer
      expect(klass.serializer.ancestors[1]).to eq(serializer)
    end

    it 'assigns type to the serializer class' do
      klass.type = :things
      klass.serializer = serializer
      expect(klass.serializer.type_val).to eq(:things)
    end

    context 'when attributes are already defined' do
      it 'applies them to the resource serializer, NOT the superclass' do
        klass.attribute :foo, :string
        expect(serializer.attribute_blocks[:foo]).to be_blank
        klass.serializer = serializer
        expect(serializer.attribute_blocks[:foo]).to_not be_present
        expect(klass.serializer.attribute_blocks[:foo]).to be_present
      end

      context 'but they are also already defined on the serializer' do
        before do
          serializer.attribute :foo do
            'predefined'
          end
          klass.attribute :foo, :string
          klass.serializer = serializer
        end

        it 'does not override the serializer' do
          block = klass.serializer.attribute_blocks[:foo]
          expect(block.call(nil)).to eq('predefined')
        end
      end
    end
  end

  it 'automatically adds id attribute' do
    expect(klass.attributes[:id]).to be_present
  end

  describe '.attribute' do
    def apply_attribute
      klass.attribute :foo, :string
    end

    it 'adds to the list of attributes' do
      apply_attribute
      expect(klass.config[:attributes].keys).to eq([:id, :foo])
    end

    it 'defaults based on configuration' do
      apply_attribute
      attribute = klass.config[:attributes][:foo]
      expect(attribute[:readable]).to eq(true)
      expect(attribute[:writable]).to eq(true)
      expect(attribute[:sortable]).to eq(true)
      expect(attribute[:filterable]).to eq(true)
    end

    context 'when attribute is :id' do
      before do
        klass.attribute :id, :string
      end

      it 'is not added to serializer attributes' do
        expect(klass.serializer.attribute_blocks.keys).to_not include(:id)
      end

      context 'and a block is passed' do
        before do
          klass.attribute :id, :string do
            'custom id'
          end
        end

        it 'configures the serializer' do
          expect(klass.serializer.id_block.call).to eq('custom id')
        end
      end
    end

    context 'when filterable' do
      it 'adds to filter list' do
        klass.attribute :foo, :string
        expect(klass.filters[:foo]).to be_present
      end

      # Either you have different block-logic or changing type
      # Either way, should override
      context 'when filter override already defined' do
        before do
          klass.attribute :foo, :string
          klass.filter :foo do
            'asdf'
          end
        end

        it 'still overrides' do
          expect {
            klass.attribute :foo, :integer
          }.to change { klass.filters[:foo] }
        end
      end
    end

    context 'when not filterable' do
      before do
        klass.attribute :foo, :string, filterable: false
      end

      it 'does not add to filter list' do
        expect(klass.filters).to_not have_key(:foo)
      end
    end

    # raise error if filtering and attr undefined

    context 'when configuration is custom' do
      before do
        klass.class_eval do
          self.attributes_readable_by_default = false
          self.attributes_writable_by_default = false
          self.attributes_sortable_by_default = false
          self.attributes_filterable_by_default = false
        end
      end

      it 'respects the overrides' do
        apply_attribute
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:readable]).to eq(false)
        expect(attribute[:writable]).to eq(false)
        expect(attribute[:sortable]).to eq(false)
        expect(attribute[:filterable]).to eq(false)
      end
    end

    context 'when type is not known' do
      before do
        klass.class_eval do
          def self.name
            'FooResource'
          end
        end
      end

      it 'raises helpful error' do
        expect {
          klass.class_eval do
            attribute :foo, :asdf
          end
        }.to raise_error(JsonapiCompliable::Errors::TypeNotFound)
      end
    end

    context 'when explicit readable flag' do
      before do
        klass.attribute :foo, :string, readable: false
      end

      it 'overrides the default' do
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:readable]).to eq(false)
      end
    end

    context 'when explicit writeable flag' do
      before do
        klass.attribute :foo, :string, writable: false
      end

      it 'overrides the default' do
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:writable]).to eq(false)
      end
    end

    context 'when explicit sortable flag' do
      before do
        klass.attribute :foo, :string, sortable: false
      end

      it 'overrides the default' do
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:sortable]).to eq(false)
      end
    end

    context 'when explicit filterable flag' do
      before do
        klass.attribute :foo, :string, filterable: false
      end

      it 'overrides the default' do
        attribute = klass.config[:attributes][:foo]
        expect(attribute[:filterable]).to eq(false)
      end
    end

    context 'when readable' do
      let(:serializer) do
        Class.new(JSONAPI::Serializable::Resource)
      end

      before do
        klass.serializer = serializer
      end

      it 'adds the attribute to the serializer' do
        klass.attribute :foo, :string
        expect(klass.serializer.attribute_blocks.keys).to include(:foo)
      end

      context 'when the serializer already defined the attribute' do
        before do
          serializer.attribute :foo do
            'predefined'
          end
          klass.serializer = serializer
        end

        it 'does not override' do
          klass.attribute :foo, :string
          block = klass.serializer.attribute_blocks[:foo]
          expect(block.call(nil)).to eq('predefined')
        end
      end
    end

    context 'when not readable' do
      it 'does not add the attribute to the serializer' do
        klass.attribute :foo, :string, readable: false
        expect(klass.serializer.attribute_blocks[:foo]).to be_nil
      end
    end
  end

  describe '.extra_attribute' do
    it 'adds to the list of extra attributes' do
      klass.extra_attribute :foo, :string
      expect(klass.config[:extra_attributes].keys).to eq([:foo])
    end

    context 'when passing a block' do
      before do
        klass.extra_attribute :foo, :string do
          'custom'
        end
      end

      it 'is used in serialization' do
        serialized = klass.serializer.attribute_blocks[:foo].call
        expect(serialized).to eq('custom')
      end
    end

    context 'when not passing a block' do
      it 'is still added to the serializer' do
        klass.extra_attribute :foo, :string
        expect(klass.serializer.attribute_blocks[:foo]).to be_present
      end

      context 'and the serializer has a block' do
        before do
          klass.serializer.class_eval do
            extra_attribute :foo do
              'serializer custom'
            end
          end
          klass.extra_attribute :foo, :string
        end

        it 'uses the serializer block' do
          expect(klass.serializer.attribute_blocks[:foo].call)
            .to eq('serializer custom')
        end
      end
    end
  end

  describe '.filter' do
    context 'when no corresponding attribute' do
      it 'raises helpful error' do
        expect {
          klass.filter :asdf
        }.to raise_error(JsonapiCompliable::Errors::AttributeError, 'AnonymousResourceClass: Tried to add filter on attribute :asdf, but could not find an attribute with that name.')
      end
    end

    context 'when corresponding but unfilterable attribute' do
      it 'raises helpful error' do
        expect {
          klass.attribute :asdf, :string, filterable: false
          klass.filter :asdf
        }.to raise_error(JsonapiCompliable::Errors::AttributeError, 'AnonymousResourceClass: Tried to add filter on attribute :asdf, but the attribute was marked :filterable => false.')
      end
    end
  end

  describe '.sort' do
    context 'when no corresponding attribute' do
      it 'raises helpful error' do
        expect {
          klass.sort :asdf
        }.to raise_error(JsonapiCompliable::Errors::AttributeError, 'AnonymousResourceClass: Tried to add sort on attribute :asdf, but could not find an attribute with that name.')
      end
    end

    context 'when corresponding but sortable attribute' do
      it 'raises helpful error' do
        expect {
          klass.attribute :asdf, :string, sortable: false
          klass.sort :asdf
        }.to raise_error(JsonapiCompliable::Errors::AttributeError, 'AnonymousResourceClass: Tried to add sort on attribute :asdf, but the attribute was marked :sortable => false.')
      end
    end
  end

  describe '#around_scoping' do
    before do
      klass.class_eval do
        self.adapter = JsonapiCompliable::Adapters::Null.new
        attr_accessor :scope
        def around_scoping(scope, query_hash)
          scope = { foo: 'bar' }
          yield scope
        end

        def resolve(scope)
          @scope = scope
          []
        end
      end
    end

    it 'modifies scope' do
      runner = JsonapiCompliable::Runner.new(klass, {})
      runner.resolve({})
      expect(runner.jsonapi_resource.scope).to eq(foo: 'bar')
    end
  end

  describe '#resolve' do
    it 'delegates to the adapter' do
      scope = double
      expect(instance.adapter).to receive(:resolve).with(scope)
      instance.resolve(scope)
    end
  end
end
