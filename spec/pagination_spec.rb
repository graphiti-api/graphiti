require "spec_helper"

RSpec.describe "pagination" do
  include_context "resource testing"
  let(:resource) { Class.new(PORO::EmployeeResource) }
  let(:base_scope) { {type: :employees} }

  subject(:ids) { records.map(&:id) }

  let!(:employee1) { PORO::Employee.create }
  let!(:employee2) { PORO::Employee.create }
  let!(:employee3) { PORO::Employee.create }
  let!(:employee4) { PORO::Employee.create }

  it "applies default pagination" do
    resource.class_eval do
      self.default_page_size = 2
    end
    expect(ids.length).to eq(2)
  end

  context "when pagination disabled" do
    before do
      resource.class_eval do
        self.default_page_size = 2
      end
    end

    context "via string query param" do
      before do
        params[:paginate] = "false"
      end

      it "does not attempt to paginate" do
        expect(ids.length).to eq(4)
      end
    end

    context "via boolean query param" do
      before do
        params[:paginate] = false
      end

      it "does not attempt to paginate" do
        expect(ids.length).to eq(4)
      end
    end
  end

  context "when requested size > 1000" do
    before do
      params[:page] = {size: 1_001}
    end

    it "raises an error" do
      expect {
        records
      }.to raise_error(Graphiti::Errors::UnsupportedPageSize)
    end
  end

  it "limits by size, offsets by number" do
    params[:page] = {number: 2, size: 2}
    expect(ids).to eq([3, 4])
  end

  # for metadata
  context "with page size 0" do
    it "should return empty array" do
      params[:page] = {size: 0}
      expect(ids).to eq([])
    end
  end

  context "when a custom pagination function is given" do
    before do
      resource.class_eval do
        paginate do |scope, page, per_page|
          scope.merge!(page: 1, per: 0)
        end
      end
    end

    it "uses the custom pagination function" do
      expect(ids).to eq([])
    end

    context "and it accesses runtime context" do
      before do
        resource.class_eval do
          paginate do |scope, page, per_page, ctx|
            scope.merge!(page: 1, per: ctx.runtime_limit)
          end
        end
      end

      it "works" do
        ctx = double(runtime_limit: 2).as_null_object
        Graphiti.with_context(ctx, {}) do
          expect(ids.length).to eq(2)
        end
      end
    end
  end


  context "when cursor pagination" do
    before do
      resource.cursor_paginatable = true
    end

    def encode(attribute, value)
      Graphiti::Util::Cursor.encode([{
        attribute: attribute,
        value: value,
        direction: :asc
      }])
    end

    context "when simple case - by id" do
      context "and 'after' given" do
        before do
          params[:page] = {after: encode(:id, employee2.id)}
        end

        it "goes through typecasting" do
          expect_any_instance_of(resource.adapter).to receive(:cursor_paginate)
            .with(anything, [hash_including(value: employee2.id)], 20)
            .and_call_original
          ids
        end

        it "works" do
          expect(ids).to eq([employee3.id, employee4.id])
        end
      end

      context "when page[size] is passed" do
        context "with 'after' param" do
          before do
            params[:page] = {
              after: encode(:id, employee1.id),
              size: 2
            }
          end
          
          it "is respected" do
            expect(ids).to eq([2, 3])
          end
        end
      end
    end

    context "when a datetime" do
      before do
        resource.attribute :created_at, :datetime
        resource.sort :created_at, cursorable: true
      end

      context "and 'after' given" do
        let(:nano_created_at) { employee2.created_at.iso8601(6) }

        before do
          params[:page] = {
            after: encode(:created_at, nano_created_at)
          }
        end

        it "passes the datetime with nanosecond precision" do
          expect_any_instance_of(resource.adapter).to receive(:cursor_paginate)
            .with(anything, [hash_including(value: nano_created_at)], 20)
            .and_call_original
          ids
        end

        it "works" do
          expect(ids).to eq([employee3.id, employee4.id])
        end
      end
    end

    context "when custom .cursor_pagination proc" do
      before do
        resource.cursor_paginate do |scope, after, size, context|
          Graphiti.context[:after_spy] = after
          Graphiti.context[:size_spy] = size
          Graphiti.context[:context_correct_spy] = Graphiti.context[:object] == context
          scope.merge!(after: after, per: size)
        end

        params[:page] = {
          after: encode(:id, employee1.id)
        }
      end

      it "is called correctly" do
        expect(ids).to eq([employee2.id, employee3.id, employee4.id])
        expect(Graphiti.context[:after_spy])
          .to eq([{attribute: :id, value: employee1.id, direction: "asc"}])
        expect(Graphiti.context[:size_spy]).to eq(20)
        expect(Graphiti.context[:context_correct_spy]).to eq(true)
      end
    end

    context "when disabled" do
      before do
        resource.cursor_paginatable = false
        params[:page] = {after: "abc123"}
      end

      it "raises friendly error" do
        expect {
          ids
        }.to raise_error(Graphiti::Errors::UnsupportedCursorPagination)
      end
    end
  end
end
