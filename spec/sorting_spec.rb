require "spec_helper"

RSpec.describe "sorting" do
  include_context "resource testing"
  let(:resource) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end
  let(:base_scope) { {type: :employees} }

  subject(:ids) { records.map(&:id) }

  before do
    PORO::Employee.create(first_name: "John", last_name: "Doe")
    PORO::Employee.create(first_name: "Jane", last_name: "Doe")

    resource.class_eval do
      attribute :first_name, :string
      attribute :last_name, :string
    end
  end

  it "defaults sort to resource default_sort" do
    params[:sort] = "-id"
    expect(ids).to eq([2, 1])
  end

  context "when *default* sorting on unknown attribute" do
    before do
      resource.default_sort = [{asdf: :asc}]
    end

    it "raises helpful error" do
      expect {
        ids
      }.to raise_error(Graphiti::Errors::AttributeError, "PORO::EmployeeResource: Tried to sort on attribute :asdf, but could not find an attribute with that name.")
    end
  end

  context "when sorting on an unknown attribute" do
    before do
      params[:sort] = "asdf"
    end

    it "raises helpful error" do
      expect {
        ids
      }.to raise_error(Graphiti::Errors::AttributeError, "PORO::EmployeeResource: Tried to sort on attribute :asdf, but could not find an attribute with that name.")
    end

    context "but there is a corresponding extra attribute" do
      before do
        resource.extra_attribute :asdf, :string
      end

      context "but it is not sortable" do
        it "raises helpful error" do
          expect {
            ids
          }.to raise_error(Graphiti::Errors::AttributeError, "PORO::EmployeeResource: Tried to sort on attribute :asdf, but the attribute was marked :sortable => false.")
        end
      end

      context "and it is sortable" do
        before do
          resource.extra_attribute :asdf, :string, sortable: true
          resource.sort :asdf do |scope, dir|
            scope[:sort] = [{id: :desc}]
            scope
          end
        end

        it "works" do
          expect(ids).to eq([2, 1])
        end
      end
    end
  end

  context "when sorting on known unsortable attribute" do
    before do
      resource.attribute :foo, :string, sortable: false
    end

    it "raises helpful error" do
      params[:sort] = "foo"
      expect {
        ids
      }.to raise_error(Graphiti::Errors::AttributeError, "PORO::EmployeeResource: Tried to sort on attribute :foo, but the attribute was marked :sortable => false.")
    end
  end

  context "when sort supports only one direction" do
    context "via attribute" do
    end

    context "via custom sort" do
      before do
        resource.sort :foo, :string, only: :asc do |scope|
          scope
        end
      end

      it "marks the sort as such" do
        expect(resource.sorts[:foo][:only]).to eq(:asc)
      end

      context "and supported sort is passed" do
        before do
          params[:sort] = "foo"
        end

        it "works" do
          expect {
            render
          }.to_not raise_error
        end
      end

      context "and unsupported sort is passed" do
        before do
          params[:sort] = "-foo"
        end

        it "raises error" do
          expect {
            render
          }.to raise_error(Graphiti::Errors::UnsupportedSort, /PORO::EmployeeResource: tried to sort on attribute :foo, but passed :desc when only :asc is supported./)
        end
      end
    end
  end

  context "when sort is guarded" do
    before do
      resource.class_eval do
        attribute :first_name, :string, sortable: :admin?

        def admin?
          !!context.admin
        end
      end

      params[:sort] = "first_name"
    end

    context "and the guard passes" do
      around do |e|
        Graphiti.with_context(OpenStruct.new(admin: true)) do
          e.run
        end
      end

      it "works" do
        expect(ids).to eq([2, 1])
      end
    end

    context "and the guard fails" do
      around do |e|
        Graphiti.with_context(OpenStruct.new(admin: false)) do
          e.run
        end
      end

      it "raises helpful error" do
        expect {
          ids
        }.to raise_error(Graphiti::Errors::AttributeError, "PORO::EmployeeResource: Tried to sort on attribute :first_name, but the guard :admin? did not pass.")
      end
    end
  end

  context "when custom sorting" do
    context "and the attribute exists" do
      before do
        resource.attribute :foo, :string
        resource.sort :foo do |scope, direction|
          scope[:sort] ||= []
          scope[:sort] << {id: :desc}
          scope
        end
      end

      it "is correctly applied" do
        params[:sort] = "foo"
        expect(ids).to eq([2, 1])
      end

      context "but it is not sortable" do
        before do
          resource.attributes[:foo][:sortable] = false
        end

        it "raises helpful error" do
          expect {
            resource.sort :foo do |scope, dir|
            end
          }.to raise_error(Graphiti::Errors::AttributeError, "PORO::EmployeeResource: Tried to add sort attribute :foo, but the attribute was marked :sortable => false.")
        end
      end
    end

    context "and the attribute does not exist" do
      before do
        resource.sort :foo, :string do |scope, dir|
          scope[:sort] ||= []
          scope[:sort] << {id: :desc}
          scope
        end
        params[:sort] = "foo"
      end

      it "works" do
        expect(ids).to eq([2, 1])
      end

      it "adds an only: [:sortable] attribute" do
        att = resource.attributes[:foo]
        expect(att[:readable]).to eq(false)
        expect(att[:writable]).to eq(false)
        expect(att[:sortable]).to eq(true)
        expect(att[:filterable]).to eq(false)
        expect(att[:type]).to eq(:string)
      end

      context "and type not given" do
        before do
          resource.attributes.delete(:foo)
        end

        it "blows up" do
          expect {
            resource.sort :foo do
            end
          }.to raise_error(Graphiti::Errors::ImplicitSortTypeMissing)
        end
      end
    end
  end

  context "when default_sort is overridden" do
    before do
      resource.class_eval do
        self.default_sort = [{id: :desc}]
      end
    end

    it "respects the override" do
      expect(ids).to eq([2, 1])
    end
  end

  context "when passing sort param" do
    before do
      params[:sort] = sort_param
    end

    subject { records.map(&:first_name) }

    context "asc" do
      let(:sort_param) { "first_name" }

      it { is_expected.to eq(%w[Jane John]) }
    end

    context "desc" do
      let(:sort_param) { "-first_name" }

      it { is_expected.to eq(%w[John Jane]) }
    end

    context "when passed multisort" do
      let(:sort_param) { "first_name,last_name" }

      before do
        PORO::Employee.create(first_name: "John", last_name: "Adams")
      end

      it "sorts correctly" do
        expect(ids).to eq([2, 3, 1])
      end
    end

    context "when given a custom sort function" do
      let(:sort_param) { "first_name" }

      before do
        resource.class_eval do
          sort_all do |scope, att, dir|
            scope[:sort] = [{id: :desc}]
            scope
          end
        end
      end

      it "uses the custom sort function" do
        expect(ids).to eq([2, 1])
      end

      context "and it accesses runtime context" do
        before do
          resource.class_eval do
            sort_all do |scope, att, dir, ctx|
              scope[:sort] = [{id: ctx.runtime_direction}]
              scope
            end
          end
        end

        it "works (desc)" do
          ctx = double(runtime_direction: :desc).as_null_object
          Graphiti.with_context(ctx, {}) do
            expect(ids).to eq([2, 1])
          end
        end

        it "works (asc)" do
          ctx = double(runtime_direction: :asc).as_null_object
          Graphiti.with_context(ctx, {}) do
            expect(ids).to eq([1, 2])
          end
        end
      end
    end
  end

  context "when cursor pagination is on" do
    before do
      resource.cursor_paginatable = true
    end

    context "and given an uncursorable sort" do
      before do
        params[:sort] = "-age"
      end

      it "applies multisort with default cursor" do
        expect_any_instance_of(resource.adapter).to receive(:order)
          .with(anything, :age, :desc).and_call_original
        expect_any_instance_of(resource.adapter).to receive(:order)
          .with(anything, :id, :asc).and_call_original
        ids
      end

      context "with custom default cursor" do
        before do
          resource.sort :created_at, :datetime, cursorable: true
          resource.default_cursor = :created_at
        end

        it "is applied correctly as multisort" do
          expect_any_instance_of(resource.adapter).to receive(:order)
            .with(anything, :age, :desc).and_call_original
          expect_any_instance_of(resource.adapter).to receive(:order)
            .with(anything, :created_at, :asc).and_call_original
          ids
        end
      end
    end

    context "and given a cursorable sort" do
      before do
        resource.sort :created_at, :datetime, cursorable: true
        params[:sort] = "-created_at"
      end

      it "does not add the default cursor to sorts" do
        expect_any_instance_of(resource.adapter).to receive(:order)
          .with(anything, :created_at, :desc).and_call_original
        ids
      end

      context "that has custom sorting logic" do
        before do
          resource.sort :identifier, :integer, cursorable: true do |scope, dir|
            scope[:sort] ||= []
            scope[:sort] << {id: dir}
            scope
          end
          params[:sort] = "-identifier"
        end

        it "honors the custom sort logic" do
          expect(ids).to eq([2, 1])
        end

        it "does not add the default cursor to sorts" do
          expect(PORO::DB).to receive(:all)
            .with(hash_including(sort: [{id: :desc}]))
            .and_call_original
          ids
        end
      end
    end

    context "and given the default cursor as sort" do
      before do
        params[:sort] = "-id"
      end

      it "does not add the default cursor to sorts" do
        expect_any_instance_of(resource.adapter).to receive(:order)
          .with(anything, :id, :desc).once.and_call_original
        ids
      end
    end
  end
end
