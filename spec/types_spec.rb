require "spec_helper"

RSpec.describe Graphiti::Types do
  after do
    described_class.instance_variable_set(:@map, nil)
  end

  describe ".[]=" do
    context "when key is string" do
      before do
        described_class["string"] = {
          params: "foo",
          read: "foo",
          test: "foo",
          write: "foo",
          kind: "foo",
          description: "foo"
        }
      end

      it "works" do
        expect(described_class[:string]).to be_present
      end
    end

    context "when value is not a hash" do
      it "raises error" do
        expect {
          described_class[:string] = "foo"
        }.to raise_error(Graphiti::Errors::InvalidType)
      end
    end

    context "when value is a hash" do
      context "with all required keys" do
        it "works" do
          type = {
            params: "foo",
            read: "foo",
            test: "foo",
            write: "foo",
            kind: "foo",
            description: "foo"
          }
          described_class[:string] = type
          expect(described_class[:string]).to eq(type)
        end
      end

      context "missing required keys" do
        it "raises error" do
          expect {
            described_class[:string] = {foo: "bar"}
          }.to raise_error(Graphiti::Errors::InvalidType)
        end
      end
    end
  end

  describe "[]" do
    it "works with symbols" do
      expect(described_class[:string]).to be_present
    end

    it "works with strings" do
      expect(described_class["string"]).to be_present
    end
  end

  describe ".map" do
    it "auto-adds canonical name" do
      expect(described_class.map.values).to all(have_key(:canonical_name))
    end

    it "auto-adds array_of_* equivalents" do
      types = described_class.map.keys
      expect(types).to include(:array_of_integers)
      expect(types).to include(:array_of_strings)
      expect(types).to include(:array_of_datetimes)
      expect(types).to include(:array_of_dates)
      expect(types).to include(:array_of_floats)
      expect(types).to include(:array_of_big_decimals)
    end
  end

  describe ".name_for" do
    it "returns canonical name" do
      expect(described_class.name_for(:array_of_integers)).to eq(:integer)
    end

    context "when passed a string" do
      it "works" do
        expect(described_class.name_for("array_of_integers"))
          .to eq(:integer)
      end
    end
  end

  describe ".flag" do
    {
      "true" => true, "TRUE" => true, "1" => true, "t" => true,
      "yes" => true, "y" => true, " true " => true, true => true,
      "false" => false, "FALSE" => false, "0" => false, "f" => false,
      "no" => false, "off" => false, false => false
    }.each_pair do |value, expected|
      it "reads #{value.inspect} as #{expected}" do
        expect(described_class.flag(value)).to eq(expected)
      end
    end

    it "is false when absent" do
      expect(described_class.flag(nil)).to eq(false)
      expect(described_class.flag("")).to eq(false)
    end

    it "is false rather than raising on a value it cannot read" do
      expect(described_class.flag("banana")).to eq(false)
    end
  end
end
