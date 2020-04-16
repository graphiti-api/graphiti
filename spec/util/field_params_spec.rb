require "spec_helper"

RSpec.describe Graphiti::Util::FieldParams do
  describe ".parse" do
    it "collects and normalizes the payload" do
      parsed = described_class.parse({
        "authors" => "first_name,last_name",
        "books" => "title"
      })
      expect(parsed).to eq({
        authors: [:first_name, :last_name],
        books: [:title]
      })
    end
  end
end
