require "spec_helper"

RSpec.describe "extra_fields" do
  include_context "resource testing"
  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end
  let(:base_scope) { {type: :employees} }

  let!(:employee) { PORO::Employee.create }

  def attributes
    json["data"][0]["attributes"]
  end

  it "does not include extra fields when not requested" do
    render
    expect(attributes.keys).to match_array(%w[first_name last_name age])
  end

  it "includes the extra fields in the response when requested" do
    params[:extra_fields] = {employees: "stack_ranking"}
    render
    expect(attributes.keys)
      .to match_array(%w[first_name last_name age stack_ranking])
  end

  context "when multiple extra attributes" do
    context "added with blocks" do
      before do
        resource.extra_attribute :a, :string do
          "a"
        end
        resource.extra_attribute :b, :string do
          "b"
        end
      end

      context "when not requested" do
        it "does not render them" do
          render
          expect(attributes.keys).to match_array(%w[first_name last_name age])
        end
      end

      context "when one is requested" do
        before do
          params[:extra_fields] = {employees: "b"}
        end

        it "is rendered" do
          render
          expect(attributes.keys).to match_array(%w[first_name last_name age b])
        end
      end
    end

    context "added without blocks" do
      before do
        allow_any_instance_of(PORO::Employee).to receive(:a) { "a" }
        allow_any_instance_of(PORO::Employee).to receive(:b) { "b" }
        resource.extra_attribute :a, :string
        resource.extra_attribute :b, :string
      end

      context "when not requested" do
        it "does not render them" do
          render
          expect(attributes.keys).to match_array(%w[first_name last_name age])
        end
      end

      context "when one is requested" do
        before do
          params[:extra_fields] = {employees: "b"}
        end

        it "is rendered" do
          render
          expect(attributes.keys).to match_array(%w[first_name last_name age b])
        end
      end
    end
  end

  context "when altering scope based on extra attrs" do
    context "when the extra attr exists" do
      before do
        resource.extra_attribute :net_worth, :integer do
          100_000
        end

        resource.on_extra_attribute :net_worth do |scope|
          {foo: "bar"}
        end
      end

      it "modifies the scope" do
        params[:extra_fields] = {employees: "net_worth"}
        expect(PORO::DB)
          .to receive(:all).with(hash_including(foo: "bar"))
          .and_return([])
        render
      end
    end

    context "when the extra attr does not exist" do
      it "raises error" do
        expect {
          resource.on_extra_attribute :net_worth do |scope|
          end
        }.to raise_error(Graphiti::Errors::ExtraAttributeNotFound, /PORO::EmployeeResource: called .on_extra_attribute :net_worth, but extra attribute :net_worth does not exist!/)
      end
    end
  end

  context "when acessing runtime context" do
    before do
      params[:extra_fields] = {employees: "runtime_id"}
    end

    it "works" do
      ctx = double(runtime_id: 789).as_null_object
      Graphiti.with_context ctx, {} do
        render
        expect(attributes["runtime_id"]).to eq(789)
      end
    end
  end

  context "when extra field is guarded" do
    before do
      params[:extra_fields] = {employees: "admin_stack_ranking"}
    end

    context "and the guard passes" do
      it "renders the field" do
        ctx = double(current_user: "admin").as_null_object
        Graphiti.with_context ctx, {} do
          render
          expect(attributes.keys).to include("admin_stack_ranking")
        end
      end
    end

    context "and the guard fails" do
      it "does not render the field" do
        ctx = double(current_user: "foo").as_null_object
        Graphiti.with_context ctx, {} do
          render
          expect(attributes.keys).to_not include("admin_stack_ranking")
        end
      end
    end
  end
end
