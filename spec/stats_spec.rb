require 'spec_helper'

RSpec.describe 'stats', type: :controller do
  controller(ApplicationController) do
    jsonapi do
      allow_stat total: :count

      allow_stat state_id: [:sum, :average, :maximum, :minimum] do
        second { |scope| scope.all[1].state_id }
      end

      allow_stat :just_symbol do
        foo { 'bar' }
      end

      allow_stat :override do
        sum { |scope, attr| 101 }
      end
    end

    def index
      render_ams(Author.all, meta: { other: 'things' })
    end
  end

  let!(:author1) { Author.create!(first_name: 'Stephen', last_name: 'King', state_id: 1) }
  let!(:author2) { Author.create!(first_name: 'Stephen', last_name: 'King', state_id: 3) }

  context 'when total count requested' do
    it 'responds with count in meta stats' do
      get :index, params: { stats: { total: 'count' } }

      expect(json['meta']['stats']).to eq({ 'total' => { 'count' => 2 } })
    end

    it 'does not override other meta content' do
      get :index, params: { stats: { total: 'count' } }

      expect(json['meta']['other']).to eq('things')
    end
  end

  context 'when specific attribute requested' do
    context 'when sum' do
      it 'responds with sum in meta stats' do
        get :index, params: { stats: { state_id: 'sum' } }

        expect(json['meta']['stats']).to eq({ 'state_id' => { 'sum' => 4 } })
      end
    end

    context 'when average' do
      it 'responds with average in meta stats' do
        get :index, params: { stats: { state_id: 'average' } }

        expect(json['meta']['stats']).to eq({ 'state_id' => { 'average' => 2.0 } })
      end
    end

    context 'when maximum' do
      it 'responds with average in meta stats' do
        get :index, params: { stats: { state_id: 'average' } }

        expect(json['meta']['stats']).to eq({ 'state_id' => { 'average' => 2.0 } })
      end
    end

    context 'when minimum' do
      it 'responds with minimum in meta stats' do
        get :index, params: { stats: { state_id: 'minimum' } }

        expect(json['meta']['stats']).to eq({ 'state_id' => { 'minimum' => 1 } })
      end
    end

    context 'when user-specified calculation' do
      it 'responds with user-specified calculation in meta stats' do
        get :index, params: { stats: { state_id: 'maximum' } }

        expect(json['meta']['stats']).to eq({ 'state_id' => { 'maximum' => 3 } })
      end
    end

    context 'when multiple stats requested' do
      it 'responds with both' do
        get :index, params: { stats: { total: 'count', state_id: 'sum,average' } }

        expect(json['meta']['stats']).to eq({
          'total' => { 'count' => 2 },
          'state_id' => { 'sum' => 4, 'average' => 2.0 }
        })
      end
    end
  end

  context 'when passing symbol to allow_stat' do
    it 'works correctly' do
      get :index, params: { stats: { just_symbol: 'foo' } }

      expect(json['meta']['stats']).to eq({
        'just_symbol' => { 'foo' => 'bar' }
      })
    end
  end

  context 'when no stats requested' do
    it 'should not be in payload' do
      get :index

      expect(json['meta']).to eq({ 'other' => 'things' })
    end
  end

  context 'when pagination requested' do
    it 'should not affect the stats' do
      get :index, params: { stats: { total: 'count' }, page: { size: 1, number: 1 } }

      expect(json['meta']['stats']).to eq({ 'total' => { 'count' => 2 } })
    end
  end

  context 'overriding a default' do
    it 'should return the override' do
      get :index, params: { stats: { override: 'sum' } }

      expect(json['meta']['stats']).to eq({ 'override' => { 'sum' => 101 } })
    end
  end

  context 'requesting ONLY stats' do
    def only_stats
      get :index, params: { stats: { total: 'count' }, page: { size: 0 } }
    end

    it 'returns empty data' do
      only_stats
      expect(json['data']).to be_empty
    end

    it 'does not query DB' do
      expect(Author).to_not receive(:find_by_sql)
      only_stats
    end

    it 'returns correct stats' do
      only_stats
      expect(json['meta']['stats']).to eq({ 'total' => { 'count' => 2 } })
    end
  end

  context 'when not AR scope' do
    before do
      controller.class_eval do
        jsonapi do
          allow_stat :total do
            count { |scope| scope.length }
          end
        end

        def index
          render_ams([Author.first])
        end
      end
    end

    it 'should stil allow custom stats' do
      get :index, params: { stats: { total: 'count' } }

      expect(json['meta']['stats']).to eq({ 'total' => { 'count' => 1 } })
    end
  end
end
