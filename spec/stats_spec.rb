require 'spec_helper'

RSpec.describe 'stats' do
  include_context 'scoping'

  before do
    resource_class.class_eval do
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
  end

  let!(:author1) { Author.create!(first_name: 'Stephen', last_name: 'King', state_id: 1) }
  let!(:author2) { Author.create!(first_name: 'Stephen', last_name: 'King', state_id: 3) }

  def json
    render(scope, meta: { other: 'things' })
  end

  context 'when total count requested' do
    before do
      params[:stats] = { total: 'count' }
    end

    it 'responds with count in meta stats' do
      expect(json['meta']['stats']).to eq({ 'total' => { 'count' => 2 } })
    end

    it 'does not override other meta content' do
      expect(json['meta']['other']).to eq('things')
    end
  end

  context 'when specific attribute requested' do
    before do
      params[:stats] = { state_id: calculation }
    end

    context 'when sum' do
      let(:calculation) { 'sum' }

      it 'responds with sum in meta stats' do
        expect(json['meta']['stats']).to eq({ 'state_id' => { 'sum' => 4 } })
      end
    end

    context 'when average' do
      let(:calculation) { 'average' }

      it 'responds with average in meta stats' do
        expect(json['meta']['stats']).to eq({ 'state_id' => { 'average' => 2.0 } })
      end
    end

    context 'when maximum' do
      let(:calculation) { 'maximum' }

      it 'responds with maximum in meta stats' do
        expect(json['meta']['stats']).to eq({ 'state_id' => { 'maximum' => 3 } })
      end
    end

    context 'when minimum' do
      let(:calculation) { 'minimum' }

      it 'responds with minimum in meta stats' do
        expect(json['meta']['stats']).to eq({ 'state_id' => { 'minimum' => 1 } })
      end
    end

    context 'when user-specified calculation' do
      let(:calculation) { 'second' }

      it 'responds with user-specified calculation in meta stats' do
        expect(json['meta']['stats']).to eq({ 'state_id' => { 'second' => 3 } })
      end
    end
  end

  context 'when multiple stats requested' do
    before do
      params[:stats] = { total: 'count', state_id: 'sum,average' }
    end

    it 'responds with both' do
      expect(json['meta']['stats']).to eq({
        'total' => { 'count' => 2 },
        'state_id' => { 'sum' => 4, 'average' => 2.0 }
      })
    end
  end

  context 'when passing symbol to allow_stat' do
    before do
      params[:stats] = { just_symbol: 'foo' }
    end

    it 'works correctly' do
      expect(json['meta']['stats']).to eq({
        'just_symbol' => { 'foo' => 'bar' }
      })
    end
  end

  context 'when no stats requested' do
    it 'should not be in payload' do
      expect(json['meta']).to eq({ 'other' => 'things' })
    end
  end

  context 'when pagination requested' do
    before do
      params[:page]   = { size: 1, number: 1 }
      params[:stats]  = { total: 'count' }
    end

    it 'should not affect the stats' do
      expect(json['meta']['stats']).to eq({ 'total' => { 'count' => 2 } })
    end
  end

  context 'overriding a default' do
    before do
      params[:stats] = { override: 'sum' }
    end

    it 'should return the override' do
      expect(json['meta']['stats']).to eq({ 'override' => { 'sum' => 101 } })
    end
  end

  context 'requesting ONLY stats' do
    before do
      params[:page] = { size: 0 }
      params[:stats] = { total: 'count' }
    end

    it 'returns empty data' do
      expect(json['data']).to be_empty
    end

    it 'does not query DB' do
      expect(Author).to_not receive(:find_by_sql)
      json
    end

    it 'returns correct stats' do
      expect(json['meta']['stats']).to eq({ 'total' => { 'count' => 2 } })
    end
  end

  context 'when not AR scope' do
    before do
      resource_class.class_eval do
        allow_stat :total do
          count { |scope| scope.length + 100 }
        end
      end
    end

    it 'should stil allow custom stats' do
      params[:stats] = { total: 'count' }
      expect(json['meta']['stats']).to eq({ 'total' => { 'count' => 102 } })
    end
  end

  context 'when requested stat not configured' do
    it 'raises error' do
      params[:stats] = { asdf: 'count' }
      expect {
        json
      }.to raise_error(JsonapiCompliable::Errors::StatNotFound, "No stat configured for calculation :count on attribute :asdf")
    end
  end
end
