require 'spec_helper'

RSpec.describe 'pagination' do
  include_context 'scoping'

  let!(:author1) { Author.create! }
  let!(:author2) { Author.create! }
  let!(:author3) { Author.create! }
  let!(:author4) { Author.create! }

  it 'applies default pagination' do
    resource_class.class_eval do
      default_page_size 2
    end
    expect(scope.resolve.length).to eq(2)
  end

  context 'when requested size > 1000' do
    before do
      params[:page] = { size: 1_001 }
    end

    it 'raises an error' do
      expect {
        scope.resolve
      }.to raise_error(JsonapiCompliable::Errors::UnsupportedPageSize)
    end
  end

  it 'limits by size, offsets by number' do
    params[:page] = { number: 2, size: 2 }
    expect(scope.resolve.map(&:id)).to eq([author3.id, author4.id])
  end

  # for metadata
  context 'with page size 0' do
    it 'should return empty array' do
      params[:page] = { size: 0 }
      expect(scope.resolve).to eq([])
    end
  end

  context 'when a custom pagination function is given' do
    before do
      resource_class.class_eval do
        paginate do |scope, page, per_page|
          scope.limit(0)
        end
      end
    end

    it 'uses the custom pagination function' do
      expect(scope.resolve).to eq([])
    end

    context 'and it accesses runtime context' do
      before do
        resource_class.class_eval do
          paginate do |scope, page, per_page, ctx|
            scope.limit(ctx.runtime_limit)
          end
        end
      end

      it 'works' do
        ctx = double(runtime_limit: 2).as_null_object
        JsonapiCompliable.with_context(ctx, {}) do
          expect(scope.resolve.length).to eq(2)
        end
      end
    end
  end
end
