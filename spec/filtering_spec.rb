require 'spec_helper'

RSpec.describe 'filtering', type: :controller do
  controller(ApplicationController) do
    jsonapi do
      allow_filter :id
      allow_filter :first_name, aliases: [:name], if: :can_filter_first_name?

      allow_filter :first_name_prefix do |scope, value|
        scope.where(['first_name like ?', "#{value}%"])
      end
    end

    def index
      render_jsonapi(Author.all)
    end

    def can_filter_first_name?
      true
    end
  end

  let!(:author1) { Author.create!(first_name: 'Stephen', last_name: 'King') }
  let!(:author2) { Author.create!(first_name: 'Agatha', last_name: 'Christie') }
  let!(:author3) { Author.create!(first_name: 'William', last_name: 'Shakesphere') }
  let!(:author4) { Author.create!(first_name: 'Harold',  last_name: 'Robbins') }

  it 'scopes correctly' do
    get :index, params: { filter: { first_name: 'Stephen' } }
    expect(json_ids).to eq([author1.id.to_s])
  end

  context 'when customized with a block' do
    it 'scopes based on the given block' do
      get :index, params: { filter: { first_name_prefix: 'Ag' } }
      expect(json_ids).to eq([author2.id.to_s])
    end
  end

  context 'when customized with alternate param name' do
    it 'filters based on the correct name' do
      get :index, params: { filter: { name: 'Stephen' } }
      expect(json_ids).to eq([author1.id.to_s])
    end
  end

  context 'when the supplied value is comma-delimited' do
    it 'parses into a ruby array' do
      get :index, params: { filter: { id: [author1.id, author2.id].join(',') } }
      expect(json_ids(true)).to match_array([author1.id, author2.id])
    end
  end

  context 'when a default filter' do
    before do
      controller.class_eval do
        jsonapi do
          default_filter :first_name do |scope|
            scope.where(first_name: 'William')
          end
        end
      end
    end

    it 'applies by default' do
      get :index
      expect(json_ids(true)).to eq([author3.id])
    end

    it 'is overrideable' do
      get :index, params: { filter: { first_name: 'Stephen' } }
      expect(json_ids(true)).to eq([author1.id])
    end

    it "is overrideable when overriding via an allowed filter's alias" do
      get :index, params: { filter: { name: 'Stephen' } }
      expect(json_ids(true)).to eq([author1.id])
    end
  end

  context 'when the filter is guarded' do
    before do
      allow(controller).to receive(:can_filter_first_name?) { false }
    end

    it 'raises an error' do
      expect {
        get :index, params: { filter: { first_name: 'Stephen' } }
      }.to raise_error(JsonapiCompliable::Errors::BadFilter)
    end
  end

  context 'when the filter is not whitelisted' do
    it 'raises an error' do
      expect {
        get :index, params: { filter: { foo: 'bar' } }
      }.to raise_error(JsonapiCompliable::Errors::BadFilter)
    end
  end
end
