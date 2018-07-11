require 'spec_helper'

# TODO: update
RSpec.describe 'persistence' do
  let(:payload) do
    {
      data: {
        type: 'employees',
        attributes: { first_name: 'Jane' }
      }
    }
  end
  let(:klass) do
    Class.new(PORO::EmployeeResource) do
      self.model = PORO::Employee

      def self.name
        'PORO::EmployeeResource'
      end
    end
  end

  around do |e|
    JsonapiCompliable.with_context({}, :create) do
      e.run
    end
  end

  it 'can persist single entities' do
    employee = klass.build(payload)
    expect(employee.save).to eq(true)
    expect(employee.data.id).to_not be_nil
    expect(employee.data.first_name).to eq('Jane')
  end

  context 'when given an attribute that does not exist' do
    before do
      payload[:data][:attributes] = { foo: 'bar' }
    end

    it 'raises appropriate error' do
      employee = klass.build(payload)
      expect {
        employee.save
      }.to raise_error(JsonapiCompliable::Errors::AttributeError, 'PORO::EmployeeResource: Tried to write attribute :foo, but could not find an attribute with that name.')
    end
  end

  context 'when given an attribute that is not writable' do
    before do
      klass.attribute :foo, :string, writable: false
      payload[:data][:attributes] = { foo: 'bar' }
    end

    it 'raises appropriate error' do
      employee = klass.build(payload)
      expect {
        employee.save
      }.to raise_error(JsonapiCompliable::Errors::AttributeError, 'PORO::EmployeeResource: Tried to write attribute :foo, but the attribute was marked :writable => false.')
    end
  end

  context 'when given a writable attribute of the wrong type' do
    before do
      klass.attribute :foo, :integer
      payload[:data][:attributes] = { foo: 'bar' }
    end

    it 'raises helpful error' do
      employee = klass.build(payload)
      expect {
        employee.save
      }.to raise_error(JsonapiCompliable::Errors::TypecastFailed, /Failed typecasting :foo! Given "bar" but the following error was raised/)
    end

    context 'and it can coerce' do
      before do
        payload[:data][:attributes] = { first_name: 1 }
      end

      it 'works' do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        expect(employee.data.first_name).to eq('1')
      end
    end
  end

  describe 'types' do
    def save(value)
      payload[:data][:attributes][:age] = value
      employee = klass.build(payload)
      employee.save
      employee.data.age
    end

    context 'when string' do
      let!(:value) { 1 }

      before do
        klass.attribute :age, :string
      end

      it 'coerces' do
        expect(save(1)).to eq('1')
      end
    end

    context 'when integer' do
      before do
        klass.attribute :age, :integer
      end

      it 'coerces strings' do
        expect(save('1')).to eq(1)
      end

      it 'allows nils' do
        expect(save(nil)).to eq(nil)
      end

      it 'does not coerce blank string to 0' do
        expect {
          save('')
        }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
      end

      context 'when cannot coerce' do
        it 'raises error' do
          expect {
            save({})
          }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
        end
      end
    end

    context 'when decimal' do
      before do
        klass.attribute :age, :decimal
      end

      it 'coerces integers' do
        expect(save(1)).to eq(BigDecimal(1))
      end

      it 'coerces strings' do
        expect(save('1')).to eq(BigDecimal(1))
      end

      it 'allows nils' do
        expect(save(nil)).to eq(nil)
      end

      context 'when cannot coerce' do
        it 'raises error' do
          expect {
            save({})
          }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
        end
      end
    end

    context 'when float' do
      before do
        klass.attribute :age, :float
      end

      it 'coerces strings' do
        expect(save('1.1')).to eq(1.1)
      end

      it 'coerces integers' do
        expect(save(1)).to eq(1.0)
      end

      it 'allows nils' do
        expect(save(nil)).to eq(nil)
      end

      context 'when cannot coerce' do
        it 'raises error' do
          expect {
            save({})
          }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
        end
      end
    end

    context 'when boolean' do
      before do
        klass.attribute :age, :boolean
      end

      it 'coerces strings' do
        expect(save('true')).to eq(true)
      end

      it 'coerces integers' do
        expect(save(1)).to eq(true)
      end

      it 'allows nils' do
        expect(save(nil)).to eq(nil)
      end

      context 'when cannot coerce' do
        it 'raises error' do
          expect {
            save({})
          }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
        end
      end
    end

    context 'when date' do
      before do
        klass.attribute :age, :date
      end

      it 'coerces Date strings to correct format' do
        expect(save('2018/01/06')).to eq(Date.parse('2018-01-06'))
      end

      it 'coerces Time strings to correct format' do
        time = Time.parse('2018/01/06 4:36pm EST')
        expect(save(time.iso8601)).to eq(Date.parse('2018-01-06'))
      end

      it 'coerces Time to correct date format' do
        time = Time.parse('2018/01/06 4:36pm EST')
        expect(save(time)).to eq(Date.parse('2018-01-06'))
      end

      it 'allows nils' do
        expect(save(nil)).to eq(nil)
      end

      context 'when only month' do
        it 'defaults to first of the month' do
          expect(save('2018/01')).to eq(Date.parse('2018-01-01'))
        end
      end

      context 'when cannot coerce' do
        it 'raises error' do
          expect {
            save({})
          }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
        end
      end
    end

    context 'when datetime' do
      before do
        klass.attribute :age, :datetime
      end

      it 'coerces Time correctly' do
        time = Time.parse('2018-01-06 4:36pm PST')
        expect(save(time)).to eq(DateTime.parse('2018-01-06 4:36pm PST'))
      end

      it 'coerces Date correctly' do
        date = Date.parse('2018-01-06')
        expect(save(date)).to eq(DateTime.parse('2018-01-06'))
      end

      it 'coerces date strings correctly' do
        expect(save('2018-01-06')).to eq(DateTime.parse('2018-01-06'))
      end

      it 'preserves date string zones' do
        result = save('2018-01-06 4:36pm PST')
        expect(result.zone).to eq('-08:00')
      end

      it 'coerces time strings correctly' do
        str = '2018-01-06 4:36pm PST'
        time = Time.parse(str)
        expect(save(time.iso8601)).to eq(DateTime.parse(str))
      end

      it 'preserves time string zones' do
        time = Time.parse('2018-01-06 4:36pm PST')
        result = save(time.iso8601)
        expect(result.zone).to eq('-08:00')
      end

      it 'allows nils' do
        expect(save(nil)).to eq(nil)
      end

      context 'when cannot coerce' do
        it 'raises error' do
          expect {
            save({})
          }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
        end
      end
    end

    context 'when hash' do
      before do
        klass.attribute :age, :hash
      end

      it 'works' do
        expect(save({ foo: 'bar' })).to eq(foo: 'bar')
      end

      # I'm OK with eventually coercing to symbols, but this seems fine
      it 'allows string keys' do
        expect(save({ 'foo' => 'bar' })).to eq('foo' => 'bar')
      end

      context 'when cannot coerce' do
        it 'raises error' do
          expect {
            save([:foo, :bar])
          }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
        end
      end
    end

    context 'when array' do
      before do
        klass.attribute :age, :array
      end

      it 'works' do
        expect(save([:foo, :bar])).to eq([:foo, :bar])
      end

      it 'raises error on single values' do
        expect {
          save(:foo)
        }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
      end

      it 'does NOT allow nils' do
        expect {
          save(nil)
        }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
      end

      context 'when cannot coerce' do
        it 'raises error' do
          expect {
            save({})
          }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
        end
      end
    end

    # test for all array_of_*
    context 'when array_of_integers' do
      before do
        klass.attribute :age, :array_of_integers
      end

      it 'works' do
        expect(save([1, 2])).to eq([1, 2])
      end

      it 'applies basic coercion' do
        expect(save(['1', '2'])).to eq([1, 2])
      end

      it 'raises error on single values' do
        expect {
          save(1)
        }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
      end

      it 'raises error on nils' do
        expect {
          save(nil)
        }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
      end

      context 'when cannot coerce' do
        it 'raises error' do
          expect {
            save(nil)
          }.to raise_error(JsonapiCompliable::Errors::TypecastFailed)
        end
      end
    end

    context 'when custom type' do
      before do
        type = Dry::Types::Definition
          .new(nil)
          .constructor { |input|
            'custom!'
          }
        JsonapiCompliable::Types[:custom] = { write: type }
        klass.attribute :age, :custom
      end

      after do
        JsonapiCompliable::Types.map.delete(:custom)
      end

      it 'works' do
        expect(save('foo')).to eq('custom!')
      end
    end
  end

  describe 'nested writes' do
    describe 'has_many' do
      let(:payload) do
        {
          data: {
            type: 'employees',
            attributes: { first_name: 'Jane' },
            relationships: {
              positions: {
                data: [{
                  type: 'positions',
                  :'temp-id' => 'abc123',
                  method: 'create'
                }]
              }
            }
          },
          included: [
            {
              type: 'positions',
              :'temp-id' => 'abc123',
              attributes: { title: 'mytitle' }
            }
          ]
        }
      end

      let(:position_model) do
        Class.new(PORO::Position) do
          validates :title, presence: true

          def self.name
            'PORO::Position'
          end
        end
      end

      let(:position_resource) do
        model = position_model
        Class.new(PORO::PositionResource) do
          self.model = model
          attribute :employee_id, :integer, only: [:writable]
          attribute :title, :string

          def self.name
            'PORO::PositionResource'
          end
        end
      end

      before do
        klass.has_many :positions, resource: position_resource
      end

      it 'works' do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.first_name).to eq('Jane')
        expect(data.positions.length).to eq(1)
        positions = data.positions
        expect(positions[0].id).to be_present
        expect(positions[0].title).to eq('mytitle')
      end

      context 'when a nested validation error' do
        before do
          payload[:included][0].delete(:attributes)
        end

        it 'responds correctly' do
          employee = klass.build(payload)
          expect(employee.save).to eq(false)
          expect(employee.data.positions[0].errors.full_messages)
            .to eq(["Title can't be blank"])
        end
      end
    end

    describe 'belongs_to' do
      let(:payload) do
        {
          data: {
            type: 'employees',
            relationships: {
              classification: {
                data: {
                  type: 'classifications',
                  :'temp-id' => 'abc123',
                  method: 'create'
                }
              }
            }
          },
          included: [
            {
              :'temp-id' => 'abc123',
              type: 'classifications',
              attributes: { description: 'classy' }
            }
          ]
        }
      end

      let(:classification_model) do
        Class.new(PORO::Classification) do
          validates :description, presence: true

          def self.name
            'PORO::Classification'
          end
        end
      end

      let(:classification_resource) do
        model = classification_model
        Class.new(PORO::ClassificationResource) do
          self.model = model
          attribute :description, :string

          def self.name
            'PORO::ClassificationResource'
          end
        end
      end

      before do
        klass.attribute :classification_id, :integer, only: [:writable]
        klass.belongs_to :classification, resource: classification_resource
      end

      it 'works' do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.classification).to be_a(classification_model)
        expect(data.classification.id).to be_present
        expect(data.classification.description).to eq('classy')
      end

      context 'when a nested validation error' do
        before do
          payload[:included][0].delete(:attributes)
        end

        it 'responds correctly' do
          employee = klass.build(payload)
          expect(employee.save).to eq(false)
          expect(employee.data.classification.errors.full_messages)
            .to eq(["Description can't be blank"])
        end
      end
    end

    describe 'has_one' do
      let(:payload) do
        {
          data: {
            type: 'employees',
            attributes: { first_name: 'Jane' },
            relationships: {
              bio: {
                data: {
                  type: 'bios',
                  :'temp-id' => 'abc123',
                  method: 'create'
                }
              }
            }
          },
          included: [
            {
              type: 'bios',
              :'temp-id' => 'abc123',
              attributes: { text: 'mytext' }
            }
          ]
        }
      end

      let(:bio_model) do
        Class.new(PORO::Bio) do
          validates :text, presence: true

          def self.name
            'PORO::Bio'
          end
        end
      end

      let(:bio_resource) do
        model = bio_model
        Class.new(PORO::BioResource) do
          self.model = model
          attribute :employee_id, :integer, only: [:writable]
          attribute :text, :string

          def self.name
            'PORO::BioResource'
          end
        end
      end

      before do
        klass.has_one :bio, resource: bio_resource
      end

      it 'works' do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.first_name).to eq('Jane')
        expect(data.bio.id).to be_present
        expect(data.bio.text).to eq('mytext')
      end

      context 'when a nested validation error' do
        before do
          payload[:included][0].delete(:attributes)
        end

        it 'responds correctly' do
          employee = klass.build(payload)
          expect(employee.save).to eq(false)
          expect(employee.data.bio.errors.full_messages)
            .to eq(["Text can't be blank"])
        end
      end
    end

    describe 'many_to_many' do
      let(:payload) do
        {
          data: {
            type: 'employees',
            attributes: { first_name: 'Jane' },
            relationships: {
              teams: {
                data: [{
                  type: 'teams',
                  :'temp-id' => 'abc123',
                  method: 'create'
                }]
              }
            }
          },
          included: [
            {
              type: 'teams',
              :'temp-id' => 'abc123',
              attributes: { name: 'ip' }
            }
          ]
        }
      end

      let(:team_model) do
        Class.new(PORO::Team) do
          validates :name, presence: true

          def self.name
            'PORO::Team'
          end
        end
      end

      let(:team_resource) do
        model = team_model
        Class.new(PORO::TeamResource) do
          self.model = model
          attribute :name, :string

          def self.name
            'PORO::TeamResource'
          end
        end
      end

      before do
        klass.many_to_many :teams,
          resource: team_resource,
          foreign_key: { team_memberships: :team_id }
      end

      it 'works' do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.first_name).to eq('Jane')
        expect(data.teams.length).to eq(1)
        expect(data.teams[0].name).to eq('ip')
      end

      context 'when a nested validation error' do
        before do
          payload[:included][0].delete(:attributes)
        end

        it 'responds correctly' do
          employee = klass.build(payload)
          expect(employee.save).to eq(false)
          expect(employee.data.teams[0].errors.full_messages)
            .to eq(["Name can't be blank"])
        end
      end
    end

    describe 'polymorphic_belongs_to' do
      let(:payload) do
        {
          data: {
            type: 'employees',
            relationships: {
              credit_card: {
                data: {
                  type: 'visas',
                  :'temp-id' => 'abc123',
                  method: 'create'
                }
              }
            }
          },
          included: [
            {
              :'temp-id' => 'abc123',
              type: 'visas',
              attributes: { number: 123456 }
            }
          ]
        }
      end

      let(:visa_model) do
        Class.new(PORO::Visa) do
          validates :number, presence: true

          def self.name
            'PORO::Visa'
          end
        end
      end

      let(:visa_resource) do
        model = visa_model
        Class.new(PORO::VisaResource) do
          self.type = :visas
          self.model = model
          attribute :number, :integer

          def self.name
            'PORO::VisaResource'
          end
        end
      end

      before do
        resource = visa_resource
        klass.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type) do
            on(:Visa).belongs_to :visa, resource: resource
          end
        end
      end

      it 'works' do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.credit_card).to be_a(PORO::Visa)
        expect(data.credit_card.id).to be_present
        expect(data.credit_card.number).to eq(123456)
        expect(data.credit_card_type).to eq(:Visa)
      end
    end

    context 'when multiple levels' do
      let(:payload) do
        {
          data: {
            type: 'employees',
            attributes: { first_name: 'Jane' },
            relationships: {
              positions: {
                data: [{
                  type: 'positions',
                  :'temp-id' => 'abc123',
                  method: 'create'
                }]
              }
            }
          },
          included: [
            {
              type: 'positions',
              :'temp-id' => 'abc123',
              attributes: { title: 'mytitle' },
              relationships: {
                department: {
                  data: {
                    type: 'departments',
                    :'temp-id' => 'abc456',
                    method: 'create'
                  }
                }
              }
            },
            {
              type: 'departments',
              :'temp-id' => 'abc456',
              attributes: { name: 'mydept' }
            }
          ]
        }
      end

      let(:position_resource) do
        Class.new(PORO::PositionResource) do
          self.model = PORO::Position
          attribute :employee_id, :integer, only: [:writable]
          attribute :department_id, :integer, only: [:writable]
          attribute :title, :string


          def self.name
            'PORO::PositionResource'
          end
        end
      end

      let(:department_resource) do
        Class.new(PORO::DepartmentResource) do
          self.model = PORO::Department

          attribute :name, :string
        end
      end

      before do
        position_resource.belongs_to :department, resource: department_resource
        klass.has_many :positions, resource: position_resource
      end

      it 'still works' do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.positions.length).to eq(1)
        expect(data.positions[0]).to be_a(PORO::Position)
        expect(data.positions[0].id).to be_present
        expect(data.positions[0].title).to eq('mytitle')
        expect(data.positions[0].department).to be_a(PORO::Department)
        expect(data.positions[0].department.id).to be_present
        expect(data.positions[0].department.name).to eq('mydept')
      end
    end
  end
end
