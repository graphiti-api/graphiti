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
      commercials = json["data"][1]["relationships"]["commercials"]
      expect(commercials["meta"]["included"]).to eq(false)
    end
  end

  describe "on__<type>--<name> syntax" do
    let!(:commercial1) do
      PORO::MastercardCommercial.create \
        mastercard_id: mastercard.id,
        runtime: 30,
        name: "foo"
    end
    let!(:commercial2) do
      PORO::MastercardCommercial.create \
        mastercard_id: mastercard.id,
        runtime: 60,
        name: "bar"
    end

    before do
      params[:include] = "on__mastercards--commercials"
    end

    # Only renderer supported for now
    context "when rendering flat json" do
      it "respects type-specific sideloads" do
        expect_any_instance_of(PORO::MastercardCommercialResource)
          .to receive(:resolve).and_call_original
        json = JSON.parse(proxy.to_json)
        expect(json["data"][0]).to_not have_key("commercials")
        expect(json["data"][1]["commercials"]).to eq([
          {"id" => commercial1.id.to_s, "runtime" => 30, "name" => "foo"},
          {"id" => commercial2.id.to_s, "runtime" => 60, "name" => "bar"}
        ])
      end

      # NB currently doesn't support on__ syntax, so 2 types
      # Can load same relationship independently but have to have same fields
      # This is something we can improve
      it "can limit fields on type-specific sideloads" do
        params[:fields] = {"commercials" => "runtime"}
        json = JSON.parse(proxy.to_json)
        expect(json["data"][0]).to_not have_key("commercials")
        expect(json["data"][1]["commercials"]).to eq([
          {"id" => commercial1.id.to_s, "runtime" => 30},
          {"id" => commercial2.id.to_s, "runtime" => 60}
        ])
      end

      context "when nesting additional sideloads off of type-specific ones" do
        let!(:actor1) do
          PORO::Actor.create \
            commercial_id: commercial1.id,
            first_name: "Jane",
            last_name: "Doe"
        end

        let!(:actor2) do
          PORO::Actor.create \
            commercial_id: commercial1.id,
            first_name: "John",
            last_name: "DoReMe"
        end

        before do
          params[:include] = "on__mastercards--commercials.actors"
        end

        it "can nest additional sideloads and limit their fields" do
          params[:fields] = {"commercials.actors" => "last_name"}
          json = JSON.parse(proxy.to_json)
          expect(json["data"][0]).to_not have_key("commercials")
          commercials = (json["data"][1]["commercials"])
          expect(commercials[0]["actors"]).to eq([
            {"id" => actor1.id.to_s, "last_name" => "Doe"},
            {"id" => actor2.id.to_s, "last_name" => "DoReMe"}
          ])
        end

        it "can filter sideloads off of type-specific ones" do
          params[:filter] = {
            "on__mastercards--commercials.actors.last_name": {
              eq: "DoReMe"
            }
          }
          json = JSON.parse(proxy.to_json)
          commercials = (json["data"][1]["commercials"])
          expect(commercials[0]["actors"]).to eq([{
            "id" => actor2.id.to_s,
            "first_name" => "John",
            "last_name" => "DoReMe"
          }])
        end

        it "can sort sideloads off of type-specific ones" do
          params[:sort] = "-on__mastercards--commercials.actors.first_name"
          json = JSON.parse(proxy.to_json)
          commercials = (json["data"][1]["commercials"])
          expect(commercials[0]["actors"]).to eq([
            {
              "id" => actor2.id.to_s,
              "first_name" => "John",
              "last_name" => "DoReMe"
            },
            {
              "id" => actor1.id.to_s,
              "first_name" => "Jane",
              "last_name" => "Doe"
            }
          ])
        end

        it "can paginate sideloads off of type-specific ones" do
          params[:page] = {
            size: 1,
            number: 2,
            "on__mastercards--commercials.size": 1,
            "on__mastercards--commercials.actors.size": 1,
            "on__mastercards--commercials.actors.number": 2
          }
          json = JSON.parse(proxy.to_json)
          commercials = (json["data"][0]["commercials"])
          expect(commercials[0]["actors"]).to eq([
            {
              "id" => actor2.id.to_s,
              "first_name" => "John",
              "last_name" => "DoReMe"
            }
          ])
        end
      end
    end
  end
end
