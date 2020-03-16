require "spec_helper"

RSpec.describe "polymorphic resource behavior" do
  include_context "resource testing"

  # Inheriting causes us to think this class is a polymorphic
  # child. Let it know this is not so, we just want a subclass for testing
  let(:resource) do
    Class.new(PORO::CreditCardResource) do
      self.polymorphic_child = false
    end
  end

  let!(:visa) { PORO::Visa.create(number: 123) }
  let!(:mastercard) { PORO::Mastercard.create(number: 456) }

  describe "persisting" do
    let(:params) do
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
    context "through derived resource" do
      let(:resproxy) { PORO::VisaResource.build(params) }
      it "works" do
        expect(resproxy.save).to be_truthy
        expect(resproxy.data).to be_a(PORO::Visa)
      end
    end
    context "through base resource" do
      let(:resproxy) { PORO::CreditCardResource.build(params) }
      it "works" do
        expect(resproxy.save).to be_truthy
        expect(resproxy.data).to be_a(PORO::Visa)
      end
    end
  end

  describe "querying" do
    context "via superclass" do
      it "works" do
        records = resource.all.to_a
        expect(records[0]).to be_a(PORO::Visa)
        expect(records[1]).to be_a(PORO::Mastercard)
        expect(records.map(&:id)).to eq([1, 1])
      end

      context "when unknown model returned" do
        around do |e|
          original = PORO::CreditCardResource.polymorphic
          PORO::CreditCardResource.polymorphic = []
          begin
            e.run
          ensure
            PORO::CreditCardResource.polymorphic = original
          end
        end

        it "raises helpful error" do
          expect {
            resource.all.to_a
          }.to raise_error(Graphiti::Errors::PolymorphicResourceChildNotFound)
        end
      end
    end

    context "via subclass" do
      it "works" do
        visas = PORO::VisaResource.all
        expect(visas[0]).to be_a(PORO::Visa)
        expect(visas[0].id).to eq(visa.id)
        expect(visas[0].number).to eq(123)
      end
    end
  end

  describe "serializing" do
    it "has correct type for each record" do
      render
      expect(json["data"][0]["type"]).to eq("visas")
      expect(json["data"][1]["type"]).to eq("mastercards")
    end

    it "uses subclass overrides" do
      render
      expect(json["data"][0]["attributes"]).to eq({
        "number" => 123,
        "description" => "visa description",
        "visa_only_attr" => "visa only"
      })
      expect(json["data"][1]["attributes"]).to eq({
        "number" => 456,
        "description" => "mastercard description"
      })
    end
  end

  describe "sideloading a subclass-specific relationship" do
    before do
      PORO::VisaReward.create(visa_id: visa.id, points: 100)
      params[:include] = "visa_rewards"
    end

    it "queries and serializes correctly" do
      render
      expect(json["data"][0]["relationships"]).to eq({
        "visa_rewards" => {
          "data" => [{"type" => "visa_rewards", "id" => "1"}]
        }
      })
      expect(json["included"]).to eq([{
        "id" => "1",
        "type" => "visa_rewards",
        "attributes" => {"points" => 100}
      }])
    end

    it "does not render the relationship when it does not pertain" do
      render
      expect(json["data"][1]).to_not have_key("relationships")
    end
  end
end
