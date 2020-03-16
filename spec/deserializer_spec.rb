require "spec_helper"

RSpec.describe Graphiti::Deserializer do
  let(:payload) do
    {
      data: {
        type: "employees",
        attributes: {first_name: "Homer", last_name: "Simpson"}
      }
    }
  end

  let(:instance) { described_class.new(payload) }

  describe "#attributes" do
    subject { instance.attributes }

    it "deserializes base attributes correctly" do
      expect(subject).to eq({
        first_name: "Homer",
        last_name: "Simpson"
      })
    end

    context "when id is present" do
      before do
        payload[:data][:id] = "123"
      end

      it "merges id into attributes" do
        expect(subject[:id]).to eq("123")
      end
    end
  end

  describe "#meta" do
    subject { instance.meta }

    it "has the correct payload path" do
      expect(subject[:payload_path]).to eq ["data"]
    end
  end

  describe "#relationships" do
    subject { instance.relationships }

    let(:payload) do
      {
        data: {
          type: "employees",
          relationships: {
            positions: {
              data: [
                {'temp-id': "abc123", type: "positions", method: "create"}
              ]
            }
          }
        },
        included: [
          {
            'temp-id': "abc123",
            type: "positions",
            attributes: {title: "specialist"}
          }
        ]
      }
    end

    it "correctly serializes relationships" do
      expect(subject).to eq({
        positions: [
          {
            meta: {
              temp_id: "abc123",
              method: :create,
              jsonapi_type: "positions",
              payload_path: ["included", 0]
            },
            attributes: {title: "specialist"},
            relationships: {}
          }
        ]
      })
    end

    context "when relationships have ids" do
      before do
        payload[:data][:relationships][:positions][:data][0][:id] = 1
      end

      it "merges id to the relationship attributes" do
        attributes = subject[:positions][0][:attributes]
        expect(attributes[:id]).to eq(1)
      end
    end

    context "when relationships are nested" do
      before do
        payload[:included][0][:relationships] = {
          department: {
            data: {
              type: "departments", 'temp-id': "def456", method: "create"
            }
          }
        }
        payload[:included] << {
          'temp-id': "def456",
          type: "departments",
          attributes: {name: "safety"}
        }
      end

      it "returns the correct nested payload" do
        expect(subject).to eq({
          positions: [
            {
              meta: {
                temp_id: "abc123",
                method: :create,
                jsonapi_type: "positions",
                payload_path: ["included", 0]
              },
              attributes: {title: "specialist"},
              relationships: {
                department: {
                  meta: {
                    jsonapi_type: "departments",
                    temp_id: "def456",
                    method: :create,
                    payload_path: ["included", 1]
                  },
                  attributes: {name: "safety"},
                  relationships: {}
                }
              }
            }
          ]
        })
      end
    end
  end

  describe "#include_hash" do
    let(:payload) do
      {
        data: {
          type: "employees",
          relationships: {
            positions: {
              data: [
                {'temp-id': "abc123", type: "positions", method: "create"},
                {'temp-id': "ghi789", type: "positions", method: "create"}
              ]
            }
          }
        },
        included: [
          {
            'temp-id': "abc123",
            type: "positions",
            attributes: {title: "pos 1"},
            relationships: {
              department: {
                data: {
                  'temp-id': "def456",
                  type: "departments",
                  method: "create"
                }
              }
            }
          },
          {
            type: "positions",
            'temp-id': "ghi789",
            method: "create",
            attributes: {title: "pos 2"},
            relationships: {
              department: {
                data: {
                  'temp-id': "d3p2",
                  method: "create",
                  type: "departments"
                }
              }
            }
          },
          {
            type: "departments",
            'temp-id': "def456",
            method: "create",
            attributes: {name: "safety"},
            relationships: {
              tags: {
                data: [
                  {'temp-id': "t4g1", type: "tags", method: "create"}
                ]
              }
            }
          },
          {
            type: "departments",
            'temp-id': "d3p1",
            method: "create",
            attributes: {name: "another dept"},
            relationships: {
              tags: {
                data: [
                  {'temp-id': "t4g1", type: "tags", method: "destroy"}
                ]
              }
            }
          },
          {
            type: "tags",
            'temp-id': "t4g1",
            attributes: {name: "foo"}
          }
        ]
      }
    end

    it "should return the correct include graph, without disassociate/deletes" do
      expect(instance.include_hash).to eq({
        positions: {
          department: {
            tags: {}
          }
        }
      })
    end
  end
end
