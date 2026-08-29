RSpec.describe Graphiti::Util::SimpleErrors do
  subject(:errors) { described_class.new(Object.new) }

  def with_translations(translations)
    original = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.store_translations(:en, graphiti: {errors: translations})
    yield
  ensure
    I18n.backend = original
  end

  describe "#add" do
    it "humanizes the code when given no message" do
      errors.add(:name, :missing)

      expect(errors[:name]).to eq(["is missing"])
    end

    it "keeps the given message" do
      errors.add(:name, :invalid, message: "must be an object")

      expect(errors[:name]).to eq(["must be an object"])
    end

    it "prefers a translation for the code" do
      with_translations(messages: {invalid: "ustmay ebay anway objectway"}) do
        errors.add(:name, :invalid, message: "must be an object")
      end

      expect(errors[:name]).to eq(["ustmay ebay anway objectway"])
    end

    it "interpolates into the message" do
      errors.add(:age, :type_error, message: "should be type %{type}", type: "integer")

      expect(errors[:age]).to eq(["should be type integer"])
    end

    it "gives a translation the attribute to name" do
      with_translations(messages: {unknown_attribute: "%{attribute} isway unknownway"}) do
        errors.add(:"data.attributes.foo", :unknown_attribute)
      end

      expect(errors[:"data.attributes.foo"]).to eq(["data.attributes.foo isway unknownway"])
    end

    it "interpolates into a translation" do
      with_translations(messages: {type_error: "ouldshay ebay ypetay %{type}"}) do
        errors.add(:age, :type_error, message: "should be type %{type}", type: "integer")
      end

      expect(errors[:age]).to eq(["ouldshay ebay ypetay integer"])
    end
  end

  describe "#full_message" do
    it "reads attribute then message" do
      expect(errors.full_message(:name, "is missing")).to eq("name is missing")
    end

    it "takes its word order from a translation" do
      with_translations(format: "%{message}: %{attribute}") do
        expect(errors.full_message(:name, "is missing")).to eq("is missing: name")
      end
    end

    it "leaves a base error alone" do
      expect(errors.full_message(:base, "is missing")).to eq("is missing")
    end
  end
end
