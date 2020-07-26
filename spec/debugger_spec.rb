# frozen_string_literal: true

RSpec.describe Graphiti::Debugger do
  context 'when disabled' do
    around do |example|
      old_value = described_class.enabled
      described_class.enabled = false
      example.run
      described_class.enabled = old_value
    end

    describe '#on_render' do
      it 'does not add data to chunks Array' do
        expect { described_class.on_render('foo', 0, 100, :foo, {}) }.not_to change(described_class.chunks, :count)
      end
    end

    describe '#on_data' do
      let(:payload) do
        {
          resource: :foo,
          parent: nil,
          params: {},
          results: []
        }
      end

      it 'does not add data to chunks Array' do
        expect { described_class.on_data('test', 0, 100, :foo, payload) }.not_to change(described_class.chunks, :count)
      end
    end
  end
end
