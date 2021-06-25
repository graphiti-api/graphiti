require "spec_helper"

RSpec.describe "pagination" do
  include_context "resource testing"
  let(:resource) { Class.new(PORO::EmployeeResource) }
  let(:base_scope) { {type: :employees} }

  subject(:ids) { records.map(&:id) }

  before do
    PORO::Employee.create
    PORO::Employee.create
    PORO::Employee.create
    PORO::Employee.create
  end

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

  shared_examples "offset-based pagination" do
    it "works" do
      expect(ids).to eq([3, 4])
    end

    context "alongside page size" do
      before do
        params[:page][:size] = 1
      end

      it "works" do
        expect(ids).to eq([3])
      end
    end

    context "alongside page number" do
      before do
        params[:page][:number] = 2
        params[:page][:size] = 1
      end

      it "works" do
        expect(ids).to eq([4])
      end
    end

    context "when a custom pagination override" do
      before do
        @spy = spy = {}
        resource.paginate do |scope, current_page, per_page, ctx, offset|
          spy[:value] = offset
          scope
        end
      end

      it "is yielded" do
        ids
        expect(@spy[:value]).to eq(2)
      end
    end
  end

  context "when offset is given" do
    before do
      params[:page] = {offset: 2}
    end

    include_examples "offset-based pagination"
  end

  context "when cursor is given" do
    context "when offset-based" do
      context "when 'after'" do
        before do
          params[:page] = {after: Base64.encode64({offset: 2}.to_json)}
        end

        include_examples "offset-based pagination"
      end

      context "when 'before'" do
        before do
          params[:page] = {before: Base64.encode64({offset: 4}.to_json), size: 3}
        end

        it "works" do
          expect(ids).to eq([1, 2, 3])
        end

        context "alongside page size" do
          before do
            params[:page][:size] = 2
          end

          it "works" do
            expect(ids).to eq([2, 3])
          end
        end

        context "alongside page number" do
          before do
            params[:page][:number] = 2
            params[:page][:size] = 1
          end

          it "raises helpful error" do
            expect { ids }.to raise_error(Graphiti::Errors::UnsupportedBeforeCursor)
          end
        end

        context "when a custom pagination override" do
          before do
            @spy = spy = {}
            resource.paginate do |scope, current_page, per_page, ctx, offset|
              spy[:value] = offset
              scope
            end
            params[:page][:size] = 1
          end

          it "is yielded" do
            ids
            expect(@spy[:value]).to eq(2)
          end
        end
      end
    end
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
end
