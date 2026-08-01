RSpec.describe Graphiti::ErrorSerializers do
  describe Graphiti::ErrorSerializers::InvalidRequest do
    let(:source) do
      Graphiti::Util::SimpleErrors.new(Object.new).tap do |errors|
        errors.add(:"filter.title", :unsupported, message: "is not supported")
      end
    end

    subject(:errors) { described_class.new(source).errors }

    it "renders one error per message" do
      source.add(:"sort.name", :unsupported, message: "is not supported")

      expect(errors.length).to eq(2)
    end

    it "reports the code, status and title" do
      expect(errors[0]).to include(
        code: "bad_request",
        status: "400",
        title: "Request Error"
      )
    end

    it "turns the attribute path into a JSON pointer" do
      source.add(:"filter.tags[0]", :unsupported, message: "is not supported")

      expect(errors.map { |error| error[:source][:pointer] })
        .to eq(["filter/title", "filter/tags/0"])
    end

    it "carries the attribute, message and code in meta" do
      expect(errors[0][:meta]).to eq(
        attribute: :"filter.title",
        message: "is not supported",
        code: :unsupported
      )
    end
  end

  describe Graphiti::ErrorSerializers::ConflictRequest do
    let(:source) do
      Graphiti::Util::SimpleErrors.new(Object.new).tap do |errors|
        errors.add(:id, :conflict, message: "does not match")
      end
    end

    subject(:error) { described_class.new(source).errors[0] }

    it "reports a conflict in the status, code and title alike" do
      expect(error).to include(
        code: "conflict",
        status: "409",
        title: "Conflict Error"
      )
    end

    it "describes the failure the same way InvalidRequest does" do
      invalid = Graphiti::ErrorSerializers::InvalidRequest.new(source).errors[0]

      expect(error[:detail]).to eq(invalid[:detail])
      expect(error[:source]).to eq(invalid[:source])
      expect(error[:meta]).to eq(invalid[:meta])
    end
  end

  describe Graphiti::ErrorSerializers::Validation do
    let(:object) do
      Class.new do
        include ActiveModel::Validations

        attr_accessor :name

        def self.name
          "Author"
        end

        validates :name, presence: true
      end.new
    end

    subject(:errors) { described_class.new(object).errors }

    before { object.valid? }

    it "renders a 422 validation error per failure" do
      expect(errors).to match([a_hash_including(
        code: "unprocessable_entity",
        status: "422",
        title: "Validation Error",
        detail: "Name can't be blank",
        source: {pointer: "/data/attributes/name"}
      )])
    end

    it "carries the attribute, message and code in meta" do
      expect(errors[0][:meta]).to eq(
        attribute: :name,
        message: "can't be blank",
        code: :blank
      )
    end

    it "is empty for an object that cannot have errors" do
      expect(described_class.new(Object.new).errors).to eq([])
    end
  end
end
