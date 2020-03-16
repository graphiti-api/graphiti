require "spec_helper"

RSpec.describe Graphiti::RequestValidator do
  let(:instance) { described_class.new(root_resource, payload) }

  let(:abstract_resource_class) do
    Class.new(Graphiti::Resource) do
      self.adapter = Graphiti::Adapters::Null
      self.abstract_class = true
    end
  end

  let(:root_resource_class) do
    Class.new(abstract_resource_class) do
      self.model = PORO::Employee
      attribute :first_name, :string
      attribute :age, :integer
      attribute :created_at, :datetime, writable: false
      attribute :salary, :integer, writable: :admin?, readable: false

      def admin?
        false
      end

      def self.name
        "RootResource"
      end
    end
  end
  let(:root_resource) { root_resource_class.new }

  let(:nested_resource_class) do
    Class.new(abstract_resource_class) do
      self.model = PORO::Position

      attribute :title, :string

      def self.name
        "NestedResource"
      end
    end
  end

  describe "#validate" do
    subject(:validate) { instance.validate }

    context "when empty payload" do
      let(:payload) { {} }

      it "validates correctly" do
        expect(validate).to eq true
        expect(instance.errors).to be_blank
      end
    end

    context "when a single level resource payload" do
      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {
              first_name: "Jane"
            }
          }
        }
      end

      it "validates correctly" do
        expect(validate).to eq true
        expect(instance.errors).to be_blank
      end

      context "when the payload contains unknown fields" do
        before do
          payload[:data][:attributes][:something_wrong] = "bad attr"
        end

        it "has an unknown attribute error" do
          expect(validate).to eq false

          expect(instance.errors).to be_added(:'data.attributes.something_wrong', :unknown_attribute)
        end
      end

      context "when the payload contains unwritable attribute" do
        before do
          payload[:data][:attributes][:created_at] = Time.now.to_s
        end

        it "has an unwritable attribute error" do
          expect(validate).to eq false

          expect(instance.errors).to be_added(:'data.attributes.created_at', :unwritable_attribute)
        end
      end

      context "when the payload contains fields protected by guards" do
        before do
          payload[:data][:attributes][:salary] = 1_000_000
        end

        context "and the guard fails" do
          before do
            allow(root_resource).to receive(:admin?).and_return(false)
          end

          it "has an unwritable attribute error" do
            expect(validate).to eq false

            expect(instance.errors).to be_added(:'data.attributes.salary', :unwritable_attribute)
          end
        end

        context "and the guard passes" do
          before do
            allow(root_resource).to receive(:admin?).and_return(true)
          end

          it "validates correctly" do
            expect(validate).to eq true
            expect(instance.errors).to be_blank
          end
        end
      end

      context "when the payload contains fields needing typecasting" do
        context "and the typecast fails" do
          before do
            payload[:data][:attributes][:age] = "foobar"
          end

          it "has a attribute access error" do
            expect(validate).to eq false

            expect(instance.errors).to be_added(:'data.attributes.age', :type_error)
            expect(instance.errors.full_messages).to eq(["data.attributes.age should be type integer"])
          end
        end

        context "and the typecast succeeds" do
          before do
            payload[:data][:attributes][:age] = "34"
          end

          it "validates correctly" do
            expect(validate).to eq true
            expect(instance.errors).to be_blank
          end

          it "correctly typecasts the fields" do
            validate

            expect(instance.deserialized_payload.attributes[:age]).to eq 34
          end
        end
      end

      context "when the resource is a polymorphic parent" do
        let(:root_resource_class) { PORO::CreditCardResource }

        let(:payload) do
          {
            data: {
              type: "visas",
              attributes: {
                number: "4222222222222222",
                visa_only_attr: "TestInheritance"
              }
            }
          }
        end

        it "recognizes the unique attributes of the child class" do
          validate

          expect(instance.errors).to be_blank
        end

        context "when updating" do
          before do
            payload["action"] = "update"
            payload[:data][:id] = 1
            payload[:filter] = {id: 1}
          end

          it "accepts the child type" do
            validate

            expect(instance.errors).to be_blank
          end
        end
      end
    end

    context "when a nested resource payload" do
      context "when has_many" do
        before do
          root_resource_class.has_many :positions, resource: nested_resource_class
        end

        let(:payload) do
          {
            data: {
              type: "employees",
              'temp-id': "23498s",
              attributes: {},
              relationships: {
                positions: {
                  data: [{
                    'temp-id': "abc123",
                    type: "positions",
                    method: "create"
                  }, {
                    'temp-id': "def456",
                    type: "positions",
                    method: "create"
                  }]
                }
              }
            },
            included: [
              {
                'temp-id': "abc123",
                type: "positions",
                attributes: {
                  title: "foo"
                }
              },
              {
                'temp-id': "def456",
                type: "positions",
                attributes: {
                  title: "bar"
                }
              }
            ]
          }
        end

        context "when the payload is correct" do
          it "validates correctly" do
            expect(validate).to eq true
            expect(instance.errors).to be_blank
          end
        end

        context "when the relationship is not writable" do
          before do
            root_resource_class.has_many :positions, resource: nested_resource_class, writable: false
            root_resource_class.has_many :positions_2, resource: nested_resource_class, writable: false

            payload[:data][:relationships][:positions_2] = {
              data: [{
                'temp-id': "abc123",
                type: "positions",
                method: "create"
              }, {
                'temp-id': "def456",
                type: "positions",
                method: "create"
              }]
            }
          end

          it "includes a single unwritable relationship error for each relationship type" do
            expect(validate).to eq false
            expect(instance.errors.count).to eq 2

            expect(instance.errors).to be_added(:'data.relationships.positions', :unwritable_relationship)
            expect(instance.errors).to be_added(:'data.relationships.positions_2', :unwritable_relationship)
          end
        end

        context "when the nested items have unknown attributes" do
          before do
            payload[:included][0][:attributes][:something] = "bad"
          end

          it "includes the error" do
            expect(validate).to eq false

            expect(instance.errors).to be_added(:'included.0.attributes.something', :unknown_attribute)
          end

          context "there are bad attributes in multiple items" do
            before do
              payload[:data][:attributes][:something] = "bad_root"
              payload[:included][1][:attributes][:something] = "bad_val"
            end

            it "includes all errors" do
              expect(validate).to eq false

              expect(instance.errors.count).to eq 3
              expect(instance.errors).to be_added(:'data.attributes.something', :unknown_attribute)
              expect(instance.errors).to be_added(:'included.0.attributes.something', :unknown_attribute)
              expect(instance.errors).to be_added(:'included.1.attributes.something', :unknown_attribute)
            end
          end
        end
      end
    end
  end

  describe "#validate" do
    subject(:validate!) { instance.validate! }

    context "when there are no request errors" do
      let(:payload) { {} }
      it { is_expected.to eq true }
    end

    context "when there are request errors" do
      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {
              something_unknown: "bad"
            }
          }
        }
      end

      it "raises an error" do
        expect {
          validate!
        }.to(raise_error { |e|
          expect(e).to be_kind_of(Graphiti::Errors::InvalidRequest)
          expect(e.errors).to eq instance.errors
        })
      end
    end
  end
end
