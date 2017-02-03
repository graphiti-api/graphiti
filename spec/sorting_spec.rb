require 'spec_helper'

RSpec.describe 'sorting', type: :controller do
  controller(ApplicationController) do
    jsonapi do
      type :authors
    end

    def index
      render_jsonapi(Author.all)
    end
  end

  before do
    Author.create!(first_name: 'Stephen', last_name: 'King')
    Author.create!(first_name: 'Philip', last_name: 'Dick')
  end

  it 'defaults sort to resource default_sort' do
    controller.resource.instance_variable_set(:@default_sort, [{ id: :asc }])
    get :index
    expect(json_ids(true)).to eq(Author.pluck(:id))
    controller.resource.instance_variable_set(:@default_sort, [{ id: :desc }])
    get :index
    expect(json_ids(true)).to eq(Author.pluck(:id).reverse)
  end

  context 'when passing sort param' do
    subject do
      get :index, params: { sort: sort_param }
      json_items.map { |n| n['first_name'] }
    end

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
        get :index, params: { sort: sort_param }
        last_names = json_items.map { |n| n['last_name'] }
        expect(last_names).to eq(%w(Dick Adams King))
      end
    end

    context 'when given a custom sort function' do
      let(:sort_param) { 'first_name' }

      before do
        controller.class.class_eval do
          jsonapi do
            sort do |scope, att, dir|
              scope.order(id: :desc)
            end
          end
        end
      end

      it 'uses the custom sort function' do
        get :index, params: { sort: sort_param }
        expect(json_ids(true)).to eq(Author.pluck(:id).reverse)
      end
    end
  end
end
