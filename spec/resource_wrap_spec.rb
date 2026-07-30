require "spec_helper"

RSpec.describe "Resource.wrap" do
  let(:klass) do
    Class.new(PORO::EmployeeResource) do
      self.model = PORO::Employee

      def self.name
        "PORO::EmployeeResource"
      end
    end
  end

  let!(:employees) do
    3.times.map { |index| PORO::Employee.create(first_name: "Employee#{index}") }
  end

  around do |e|
    Graphiti.with_context({}, :find) do
      e.run
    end
  end

  it "returns only the models it was given" do
    proxy = klass.wrap([employees[1]])

    expect(proxy.data.map(&:first_name)).to eq(["Employee1"])
  end

  it "does not resolve the scope" do
    expect_any_instance_of(Graphiti::Scope).to_not receive(:resolve)

    klass.wrap([employees[1]]).data
  end

  it "decorates the models so they can be serialized" do
    proxy = klass.wrap([employees[1]])

    expect(proxy.data.first.instance_variable_get(:@__graphiti_serializer))
      .to eq(klass.serializer)
  end

  it "accepts an empty collection" do
    proxy = klass.wrap([])

    expect(proxy.data).to eq([])
  end

  it "accepts a single model" do
    proxy = klass.wrap(employees[0])

    expect(proxy.data.first_name).to eq("Employee0")
  end

  describe "when a model does not match the resource" do
    let(:position) { PORO::Position.create(title: "Manager") }

    it "raises rather than rendering with the wrong serializer" do
      expect {
        klass.wrap([position])
      }.to raise_error(Graphiti::Errors::InvalidWrapModel, /given a PORO::Position/)
    end

    it "raises when only one model in the collection is wrong" do
      expect {
        klass.wrap([employees[0], position])
      }.to raise_error(Graphiti::Errors::InvalidWrapModel)
    end

    it "raises when given a single model" do
      expect {
        klass.wrap(position)
      }.to raise_error(Graphiti::Errors::InvalidWrapModel)
    end

    it "does not decorate any of the models" do
      begin
        klass.wrap([employees[0], position])
      rescue Graphiti::Errors::InvalidWrapModel
      end

      expect(employees[0].instance_variable_get(:@__graphiti_serializer))
        .to be_nil
    end

    it "names the expected model in the message" do
      expect {
        klass.wrap([position])
      }.to raise_error(/this resource is for PORO::Employee/)
    end
  end

  describe "when a model is a subclass of the resource's model" do
    let(:gold_visa) { PORO::GoldVisa.create(number: 1) }

    it "is allowed" do
      proxy = PORO::VisaResource.wrap([gold_visa])

      expect(proxy.data).to eq([gold_visa])
    end
  end

  describe "when the resource is a polymorphic parent" do
    it "allows any of its children's models" do
      visa = PORO::Visa.create(number: 1)
      proxy = PORO::CreditCardResource.wrap([visa])

      expect(proxy.data).to eq([visa])
    end

    it "still raises the polymorphic error for an unknown model" do
      expect {
        PORO::CreditCardResource.wrap([PORO::Position.create(title: "Manager")])
      }.to raise_error(Graphiti::Errors::PolymorphicResourceChildNotFound)
    end
  end
end
