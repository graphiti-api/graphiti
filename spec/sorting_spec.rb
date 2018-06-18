require 'spec_helper'

RSpec.describe 'sorting' do
  include JsonHelpers
  include_context 'resource testing'
  let(:resource) { Class.new(PORO::EmployeeResource).new }
  let(:base_scope) { { type: :employees } }

  subject(:ids) { scope.resolve.map(&:id) }

  before do
    PORO::Employee.create(first_name: 'John', last_name: 'Doe')
    PORO::Employee.create(first_name: 'Jane', last_name: 'Doe')
  end

  it 'defaults sort to resource default_sort' do
    expect(ids).to eq([1,2])
  end

  context 'when default_sort is overridden' do
    before do
      resource.class.class_eval do
        default_sort([{ id: :desc }])
      end
    end

    it 'respects the override' do
      expect(ids).to eq([2,1])
    end
  end

  context 'when passing sort param' do
    before do
      params[:sort] = sort_param
    end

    subject { scope.resolve.map(&:first_name) }

    context 'asc' do
      let(:sort_param) { 'first_name' }

      it { is_expected.to eq(%w(Jane John)) }
    end

    context 'desc' do
      let(:sort_param) { '-first_name' }

      it { is_expected.to eq(%w(John Jane)) }
    end

    context 'when prefixed with type' do
      let(:sort_param) { 'employees.first_name' }

      it { is_expected.to eq(%w(Jane John)) }
    end

    context 'when passed multisort' do
      let(:sort_param) { 'first_name,last_name' }

      before do
        PORO::Employee.create(first_name: 'John', last_name: 'Adams')
      end

      it 'sorts correctly' do
        expect(ids).to eq([2, 3, 1])
      end
    end

    context 'when given a custom sort function' do
      let(:sort_param) { 'first_name' }

      before do
        resource.class.class_eval do
          sort do |scope, att, dir|
            scope[:sort] = [{ id: :desc }]
            scope
          end
        end
      end

      it 'uses the custom sort function' do
        expect(ids).to eq([2, 1])
      end

      context 'and it accesses runtime context' do
        before do
          resource.class.class_eval do
            sort do |scope, att, dir, ctx|
              scope[:sort] = [{ id: ctx.runtime_direction }]
              scope
            end
          end
        end

        it 'works (desc)' do
          ctx = double(runtime_direction: :desc).as_null_object
          JsonapiCompliable.with_context(ctx, {}) do
            expect(ids).to eq([2,1])
          end
        end

        it 'works (asc)' do
          ctx = double(runtime_direction: :asc).as_null_object
          JsonapiCompliable.with_context(ctx, {}) do
            expect(ids).to eq([1,2])
          end
        end
      end
    end
  end
end
