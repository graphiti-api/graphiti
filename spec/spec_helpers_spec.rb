require "spec_helper"

describe Graphiti::SpecHelpers do
  include Graphiti::SpecHelpers

  attr_accessor :response

  let(:instance) { klass.new }

  let(:json) do
    {
      data: [
        {
          type: "employees",
          id: "100",
          attributes: {first_name: "John"},
          relationships: {
            positions: {
              data: [
                {
                  type: "positions",
                  id: "200"
                }
              ],
              links: {
                related: "http://example.com/positions?filter[employee_id]=100"
              }
            }
          }
        }
      ],
      included: [
        {
          type: "positions",
          id: "200",
          attributes: {title: "Manager"},
          relationships: {
            department: {
              data: {
                type: "departments",
                id: "300"
              }
            }
          }
        },
        {
          type: "departments",
          id: "300",
          attributes: {name: "Engineering"}
        }
      ]
    }.with_indifferent_access
  end

  describe "#link" do
    it "returns the relevant link" do
      link = jsonapi_data[0].link(:positions, :related)
      expect(link).to eq("http://example.com/positions?filter[employee_id]=100")
    end

    context "when no links" do
      before do
        json[:data][0][:relationships][:positions].delete(:links)
      end

      it "raises helpful error" do
        expect {
          jsonapi_data[0].link(:positions, :related)
        }.to raise_error(Graphiti::SpecHelpers::Errors::LinksNotFound, "Relationship with name 'positions' has no links!")
      end
    end
  end

  describe "#flatten" do
    it "works" do
      expect(jsonapi_data.flatten.map(&:id)).to eq([100])
    end
  end

  describe "#sideloads/sideload" do
    context "when relation is an array" do
      it "returns relevant node" do
        sl = jsonapi_data[0].sideloads(:positions)
        expect(sl.map(&:attributes)).to eq([{
          "id" => "200",
          "jsonapi_type" => "positions",
          "title" => "Manager"
        }])
      end
    end

    context "when relation is a hash" do
      it "returns relevant node" do
        sl = jsonapi_included[0].sideload(:department)
        expect(sl.attributes).to eq({
          "id" => "300",
          "jsonapi_type" => "departments",
          "name" => "Engineering"
        })
      end
    end

    context "when not found" do
      it "raises helpful error" do
        expect {
          jsonapi_data[0].sideloads(:foo)
        }.to raise_error(Graphiti::SpecHelpers::Errors::SideloadNotFound, "Relationship with name 'foo' not found!")
      end
    end

    context "when nil" do
      before do
        json[:included][0][:relationships][:department][:data] = nil
      end

      it "returns nil" do
        expect(jsonapi_included[0].sideload(:department)).to be_nil
      end
    end
  end

  describe "#jsonapi_data" do
    context "when data is hash" do
      before do
        json[:data] = json[:data][0]
      end

      it "returns a node" do
        expect(jsonapi_data.is_a?(Graphiti::SpecHelpers::Node)).to eq(true)
        expect(jsonapi_data.id).to eq(100)
        expect(jsonapi_data.jsonapi_type).to eq("employees")
        expect(jsonapi_data.first_name).to eq("John")
      end

      context "when trying to access missing attribute" do
        it "raises helpful error" do
          expect {
            jsonapi_data.foo
          }.to raise_error(Graphiti::SpecHelpers::Errors::NoAttribute, "No attribute 'foo' in JSON response node!")
        end
      end
    end

    context "when data is an array" do
      it "returns an array of nodes" do
        expect(jsonapi_data.is_a?(Array)).to eq(true)
        expect(jsonapi_data.length).to eq(1)
        expect(jsonapi_data[0].is_a?(Graphiti::SpecHelpers::Node)).to eq(true)
        expect(jsonapi_data[0].id).to eq(100)
        expect(jsonapi_data[0].jsonapi_type).to eq("employees")
        expect(jsonapi_data[0].first_name).to eq("John")
      end
    end

    context "when no data" do
      before do
        json.delete("data")
      end

      it "raises helpful error" do
        expect {
          jsonapi_data
        }.to raise_error(Graphiti::SpecHelpers::Errors::NoData)
      end
    end
  end

  describe "#jsonapi_included" do
    it "returns an array of nodes from included section of payload" do
      i = jsonapi_included
      expect(i.is_a?(Array)).to eq(true)
      expect(i.length).to eq(2)
      expect(i[0].id).to eq(200)
      expect(i[0].jsonapi_type).to eq("positions")
      expect(i[0].title).to eq("Manager")
      expect(i[1].id).to eq(300)
      expect(i[1].jsonapi_type).to eq("departments")
      expect(i[1].name).to eq("Engineering")
    end
  end

  describe "#jsonapi_errors" do
    let(:json) do
      {
        errors: [
          {
            code: "unprocessable_entity",
            status: "422",
            title: "Validation Error",
            detail: "Name can't be blank",
            source: {pointer: "/data/attributes/name"},
            meta: {
              attribute: :name,
              message: "can't be blank",
              code: :blank
            }
          }
        ]
      }.with_indifferent_access
    end

    it "returns a proxy that acts as array" do
      errors = jsonapi_errors
      expect(errors.length).to eq(1)
      expect(errors[0].attribute).to eq(:name)
      expect(errors[0].status).to eq("422")
      expect(errors[0].title).to eq("Validation Error")
      expect(errors[0].detail).to eq("Name can't be blank")
      expect(errors[0].code).to eq(:blank)
      expect(errors[0].message).to eq("can't be blank")
    end

    it "finds errors via attribute name" do
      errors = jsonapi_errors
      expect(errors.name.message).to eq("can't be blank")
    end

    it "can render simple hash" do
      errors = jsonapi_errors
      expect(errors.to_h).to eq({
        name: "can't be blank"
      })
    end
  end

  describe "#jsonapi_meta" do
    context "when data is present" do
      before do
        json[:meta] = {foo: "bar"}
      end

      it "returns the hash" do
        expect(jsonapi_meta).to eq({"foo" => "bar"})
      end
    end

    context "when no meta" do
      before do
        json.delete("meta")
      end

      it "raises helpful error" do
        expect {
          jsonapi_meta
        }.to raise_error(Graphiti::SpecHelpers::Errors::NoMeta)
      end
    end
  end
end
