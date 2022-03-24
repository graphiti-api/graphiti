require "spec_helper"

RSpec.describe "stats" do
  include_context "resource testing"
  let(:resource) { Class.new(PORO::EmployeeResource) }
  let(:base_scope) { {type: :employees} }

  let!(:employee1) do
    PORO::Employee.create first_name: "Stephen",
      last_name: "King"
  end
  let!(:employee1) do
    PORO::Employee.create first_name: "Stephen",
      last_name: "King"
  end

  context "when total count requested" do
    before do
      params[:stats] = {total: "count"}
      resource.class_eval do
        stat total: :count
      end
    end

    it "responds with count in meta stats" do
      render
      expect(json["meta"]["stats"])
        .to eq({"total" => {"count" => "poro_count_total"}})
    end

    # Must be integration spec
    xit "does not override other meta content" do
      render(meta: {other: "things"})
      expect(json["meta"]["other"]).to eq("things")
    end
  end

  context "when specific attribute requested" do
    before do
      params[:stats] = {age: calculation}
    end

    context "when sum" do
      let(:calculation) { "sum" }

      before do
        resource.class_eval do
          stat age: [:sum]
        end
      end

      it "responds with sum in meta stats" do
        render
        expect(json["meta"]["stats"])
          .to eq({"age" => {"sum" => "poro_sum_age"}})
      end
    end

    context "when average" do
      let(:calculation) { "average" }

      before do
        resource.class_eval do
          stat age: [:average]
        end
      end

      it "responds with average in meta stats" do
        render
        expect(json["meta"]["stats"])
          .to eq({"age" => {"average" => "poro_average_age"}})
      end
    end

    context "when maximum" do
      let(:calculation) { "maximum" }

      before do
        resource.class_eval do
          stat age: [:maximum]
        end
      end

      it "responds with maximum in meta stats" do
        render
        expect(json["meta"]["stats"])
          .to eq({"age" => {"maximum" => "poro_maximum_age"}})
      end
    end

    context "when minimum" do
      let(:calculation) { "minimum" }

      before do
        resource.class_eval do
          stat age: [:minimum]
        end
      end

      it "responds with minimum in meta stats" do
        render
        expect(json["meta"]["stats"])
          .to eq({"age" => {"minimum" => "poro_minimum_age"}})
      end
    end

    context "when user-specified calculation" do
      let(:calculation) { "second" }

      before do
        resource.class_eval do
          stat :age do
            second { |scope| 1337 }
          end
        end
      end

      it "responds with user-specified calculation in meta stats" do
        render
        expect(json["meta"]["stats"])
          .to eq({"age" => {"second" => 1337}})
      end

      context "that requires access to context" do
        let(:ctx) do
          double "stat context",
            current_user: double.as_null_object,
            my_stat: 1338
        end

        before do
          resource.class_eval do
            stat :age do
              second { |_, _, context| context.my_stat }
            end
          end
        end

        it "works" do
          Graphiti.with_context(ctx) { render }
          expect(json["meta"]["stats"])
            .to eq({"age" => {"second" => 1338}})
        end
      end

      context "that resolves from response data" do
        class Results < SimpleDelegator
          attr_accessor :meta

          def initialize(array, meta:)
            super(array)
            @meta = meta
          end
        end

        before do
          resource.class_eval do
            stat :age do
              second { |_, _, _, data| data.meta[:stats][:age] }
            end

            def resolve(scope)
              Results.new(super, meta: {stats: {age: "from meta!"}})
            end
          end
        end

        it "works" do
          render
          expect(json["meta"]["stats"])
            .to eq({"age" => {"second" => "from meta!"}})
        end
      end
    end
  end

  context "when multiple stats requested" do
    before do
      params[:stats] = {total: "count", age: "sum,average"}
    end

    before do
      resource.class_eval do
        stat total: :count
        stat age: [:sum, :average]
      end
    end

    it "responds with both" do
      render
      expect(json["meta"]["stats"]).to eq({
        "total" => {"count" => "poro_count_total"},
        "age" => {"sum" => "poro_sum_age", "average" => "poro_average_age"}
      })
    end
  end

  context "when passing symbol to stat" do
    before do
      params[:stats] = {age: "sum"}
    end

    before do
      resource.class_eval do
        stat age: :sum
      end
    end

    it "works correctly" do
      render
      expect(json["meta"]["stats"]).to eq({
        "age" => {"sum" => "poro_sum_age"}
      })
    end
  end

  context "when no stats requested" do
    # TODO: must be integration tested
    xit "should not be in payload" do
      render(meta: {other: "things"})
      expect(json["meta"]).to eq({"other" => "things"})
    end
  end

  context "when pagination requested" do
    before do
      params[:page] = {size: 1, number: 1}
      params[:stats] = {total: "count"}
    end

    # TODO: must be integration tested
    xit "should not affect the stats" do
      expect(json["meta"]["stats"]).to eq({"total" => {"count" => 2}})
    end
  end

  context "overriding a default" do
    before do
      params[:stats] = {age: "sum"}
    end

    before do
      resource.class_eval do
        stat :age do
          sum { |scope, attr| "overridden_#{attr}" }
        end
      end
    end

    it "should return the override" do
      render
      expect(json["meta"]["stats"])
        .to eq({"age" => {"sum" => "overridden_age"}})
    end
  end

  context "requesting ONLY stats" do
    before do
      params[:page] = {size: 0}
      params[:stats] = {total: "count"}
    end

    before do
      resource.class_eval do
        stat total: [:count]
      end
    end

    it "returns empty data" do
      render
      expect(json["data"]).to be_empty
    end

    it "does not query DB" do
      expect(PORO::DB).to_not receive(:all)
      render
    end

    it "returns correct stats" do
      render
      expect(json["meta"]["stats"])
        .to eq({"total" => {"count" => "poro_count_total"}})
    end
  end

  context "when requested stat not configured" do
    it "raises error" do
      params[:stats] = {asdf: "count"}
      expect {
        render
      }.to raise_error(Graphiti::Errors::StatNotFound, "No stat configured for calculation :count on attribute :asdf")
    end
  end
end
