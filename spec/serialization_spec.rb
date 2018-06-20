require 'spec_helper'

RSpec.describe 'serialization' do
  include JsonHelpers
  include_context 'resource testing'
  let(:resource) do
    Class.new(PORO::ApplicationResource) do
      self.type = :employees
      def self.name
        'PORO::EmployeeResource'
      end
    end
  end
  let(:base_scope) { { type: :employees } }

  context 'when serializer is automatically generated' do
    it 'generates a serializer class' do
      expect(resource.serializer.ancestors)
        .to include(JSONAPI::Serializable::Resource)
    end

    it 'has same type as resource' do
      expect(resource.serializer.type_val).to eq(:employees)
    end

    it 'has all readable attributes of resource' do
      resource.attribute :foo, :string
      expect(resource.serializer.attribute_blocks.keys).to include(:foo)
    end

    it 'has all readable sideloads of the resource' do
      resource.allow_sideload :foobles
      resource.allow_sideload :barble
      expect(resource.serializer.relationship_blocks.keys)
        .to eq([:foobles, :barble])
    end

    it 'renders correctly' do
      PORO::Employee.create(first_name: 'John')
      resource.attribute :first_name, :string
      render
      expect(json['data'][0]['type']).to eq('employees')
      expect(json['data'][0]['attributes']).to eq('first_name' => 'John')
    end

    context 'when the resource attribute has a block' do
      before do
        resource.attribute :foo, :string do
          'without object'
        end
        resource.attribute :bar, :string do
          @object.first_name.upcase
        end
      end

      it 'is used in serialization' do
        PORO::Employee.create(first_name: 'John')
        render
        data = json['data'][0]
        attributes = data['attributes']
        expect(attributes).to eq({
          'foo' => 'without object',
          'bar' => 'JOHN'
        })
      end
    end

    context 'when the resource has a different serializer than the model' do
      let(:serializer) do
        Class.new(JSONAPI::Serializable::Resource) do
          attribute :first_name do
            'override'
          end
        end
      end

      before do
        PORO::Employee.create(first_name: 'John')
        resource.serializer = serializer
      end

      it 'uses the resource serializer no matter what' do
        render
        expect(json['data'][0]['type']).to eq('employees')
        expect(json['data'][0]['attributes']).to eq('first_name' => 'override')
      end
    end

    context 'when a sideload is not readable' do
      before do
        resource.allow_sideload :hidden, readable: false
      end

      it 'is not applied to the serializer' do
        expect(resource.serializer.relationship_blocks.keys)
          .to_not include(:hidden)
      end
    end

    context 'when a sideload macro not readable' do
      before do
        resource.belongs_to :hidden, readable: false
      end

      it 'is not applied to the serializer' do
        expect(resource.serializer.relationship_blocks.keys)
          .to_not include(:hidden)
      end
    end

    context 'when an attribute is not readable' do
      before do
        resource.attribute :foo, :string, readable: false
      end

      it 'is not applied to the serializer' do
        expect(resource.serializer.attribute_blocks.keys).to eq([])
      end
    end

    context 'when an attribute is conditionally readable' do
      before do
        PORO::Employee.create(first_name: 'John')
        resource.class_eval do
          attribute :first_name, :string
          attribute :foo, :string, readable: :admin? do
            'bar'
          end

          def admin?
            !!context.admin
          end
        end
      end

      context 'and the guard passes' do
        around do |e|
          JsonapiCompliable.with_context(OpenStruct.new(admin: true)) do
            e.run
          end
        end

        it 'is serialized' do
          render
          expect(json['data'][0]['attributes']['foo']).to eq('bar')
        end
      end

      context 'and the guard fails' do
        around do |e|
          JsonapiCompliable.with_context(OpenStruct.new(admin: false)) do
            e.run
          end
        end

        it 'is not serialized' do
          render
          expect(json['data'][0]['attributes']).to_not have_key('foo')
        end
      end
    end
  end

  context 'when serializer is explicitly assigned' do
    it 'generates a serializer class' do
      expect(resource.serializer.ancestors)
        .to include(JSONAPI::Serializable::Resource)
    end

    it 'has same type as resource' do
      expect(resource.serializer.type_val).to eq(:employees)
    end

    it 'has all readable attributes of resource' do
      resource.attribute :foo, :string
      expect(resource.serializer.attribute_blocks.keys).to eq([:foo])
    end

    context 'when an attribute is not readable' do
      before do
        resource.attribute :foo, :string, readable: false
      end

      it 'is not applied to the serializer' do
        expect(resource.serializer.attribute_blocks.keys).to eq([])
      end
    end
  end

  describe 'extra attributes' do
    before do
      PORO::Employee.create(first_name: 'John')
      resource.attribute :foo, :string do
        'bar'
      end
      resource.extra_attribute :first_name, :string
    end

    it 'adds extra attributes to the serializer' do
      params[:extra_fields] = { employees: 'first_name' }
      expect(resource.serializer.attribute_blocks.keys)
        .to match_array([:first_name, :foo])
      render
      expect(json['data'][0]['attributes']).to eq({
        'foo' => 'bar',
        'first_name' => 'John'
      })
    end

    it 'does not render extra attributes if not requested' do
      render
      expect(json['data'][0]['attributes']).to_not have_key('first_name')
    end

    context 'when passing a block' do
      before do
        resource.serializer.attribute_blocks.delete(:first_name)
        resource.extra_attribute :first_name, :string do
          'im extra, serialized'
        end
      end

      it 'is used during serialization' do
        params[:extra_fields] = { employees: 'first_name' }
        render
        expect(json['data'][0]['attributes']['first_name'])
          .to eq('im extra, serialized')
      end
    end
  end
end
