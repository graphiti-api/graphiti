require 'spec_helper'

RSpec.describe 'sorting' do
  include_context 'scoping'

  before do
    Author.create!(first_name: 'Stephen', last_name: 'King')
    Author.create!(first_name: 'Philip', last_name: 'Dick')
  end

  it 'defaults sort to resource default_sort' do
    expect(scope.resolve.map(&:id)).to eq(Author.pluck(:id))
  end

  context 'when default_sort is overridden' do
    before do
      resource_class.class_eval do
        default_sort([{ id: :desc }])
      end
    end

    it 'respects the override' do
      expect(scope.resolve.map(&:id)).to eq(Author.pluck(:id).reverse)
    end
  end

  context 'when passing sort param' do
    before do
      params[:sort] = sort_param
    end

    subject { scope.resolve.map(&:first_name) }

    context 'asc' do
      let(:sort_param) { 'first_name' }

      it { is_expected.to eq(%w(Philip Stephen)) }
    end

    context 'desc' do
      let(:sort_param) { '-first_name' }

      it { is_expected.to eq(%w(Stephen Philip)) }
    end

    context 'when prefixed with type' do
      let(:sort_param) { 'authors.first_name' }

      it { is_expected.to eq(%w(Philip Stephen)) }
    end

    context 'when passed multisort' do
      let(:sort_param) { 'first_name,last_name' }

      before do
        Author.create(first_name: 'Stephen', last_name: 'Adams')
      end

      it 'sorts correctly' do
        expect(scope.resolve.map(&:last_name)).to eq(%w(Dick Adams King))
      end
    end

    context 'when given a custom sort function' do
      let(:sort_param) { 'first_name' }

      before do
        resource_class.class_eval do
          sort do |scope, att, dir|
            scope.order(id: :desc)
          end
        end
      end

      it 'uses the custom sort function' do
        expect(scope.resolve.map(&:id)).to eq(Author.pluck(:id).reverse)
      end

      context 'and it accesses runtime context' do
        before do
          resource_class.class_eval do
            sort do |scope, att, dir, ctx|
              scope.order(id: ctx.runtime_direction)
            end
          end
        end

        it 'works (desc)' do
          ctx = double(runtime_direction: :desc).as_null_object
          JsonapiCompliable.with_context(ctx, {}) do
            expect(scope.resolve.map(&:id)).to eq(Author.pluck(:id).reverse)
          end
        end

        it 'works (asc)' do
          ctx = double(runtime_direction: :asc).as_null_object
          JsonapiCompliable.with_context(ctx, {}) do
            expect(scope.resolve.map(&:id)).to eq(Author.pluck(:id))
          end
        end
      end
    end
  end
end
