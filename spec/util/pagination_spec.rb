require 'spec_helper'

RSpec.describe JsonapiCompliable::Util::Pagination do
  describe '.zero?' do
    subject { described_class.zero?(params) }

    context 'when no page specified' do
      let(:params) { { } }

      it { is_expected.to be(false) }
    end

    context 'when params symbolized' do
      context 'when page size is 0' do
        let(:params) { { page: { size: 0 } } }

        it { is_expected.to be(true) }
      end

      context 'when page size is "0"' do
        let(:params) { { page: { size: '0' } } }

        it { is_expected.to be(true) }
      end

      context 'when page size > 0 as string' do
        let(:params) { { page: { size: '1' } } }

        it { is_expected.to be(false) }
      end

      context 'when page size > 0 as integer' do
        let(:params) { { page: { size: 1 } } }

        it { is_expected.to be(false) }
      end
    end

    context 'when params stringified' do
      context 'when page size is 0' do
        let(:params) { { 'page' => { 'size' => 0 } } }

        it { is_expected.to be(true) }
      end

      context 'when page size is "0"' do
        let(:params) { { 'page' => { 'size' => '0' } } }

        it { is_expected.to be(true) }
      end

      context 'when page size > 0 as string' do
        let(:params) { { 'page' => { 'size' => '1' } } }

        it { is_expected.to be(false) }
      end

      context 'when page size > 0 as integer' do
        let(:params) { { 'page' => { 'size' => 1 } } }

        it { is_expected.to be(false) }
      end
    end
  end
end
