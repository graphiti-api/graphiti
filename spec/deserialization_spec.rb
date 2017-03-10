require 'spec_helper'

RSpec.describe 'deserialization' do
  let(:klass) do
    Class.new do
      include JsonapiCompliable::Base
      jsonapi { }
      attr_accessor :params
    end
  end

  let(:instance) { klass.new }

  let(:payload) do
    {
      data: {
        type: 'authors',
        attributes: { first_name: 'Stephen', last_name: 'King' },
        relationships: {
          state: {
            data: {
              type: 'states',
              attributes: { name: 'virginia' },
            }
          },
          books: {
            data: [
              { type: 'books', attributes: { title: 'The Shining' } }
            ]
          }
        }
      }
    }
  end

  describe '#deserialize_jsonapi!' do
    before do
      instance.params = payload
    end

    it 'preserves raw params as raw_params' do
      instance.deserialize_jsonapi!

      expect(instance.raw_params).to eq(payload)
    end

    it 'sets params to a rails-friendly payload' do
      instance.deserialize_jsonapi!
      expected = {
        author: {
          first_name: 'Stephen',
          last_name: 'King',
          state_attributes: {
            name: 'virginia'
          },
          books_attributes: [
            { title: 'The Shining' }
          ]
        }
      }
      expect(instance.params).to eq(expected)
    end

    it 'does not overwrite deserialized param namespace with something from raw params' do
      payload[:author] = 'Claudia y Inez Bachman'
      instance.deserialize_jsonapi!
      expect(instance.params[:author]).to be_a(Hash)
    end
  end
end
