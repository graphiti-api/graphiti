require 'spec_helper'

RSpec.describe 'deserialization', type: :controller do
  controller(ApplicationController) do
    jsonapi { }
  end

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
      controller.params = payload
    end

    it 'preserves raw params as raw_params' do
      controller.deserialize_jsonapi!

      if Rails::VERSION::MAJOR == 4
        expect(controller.raw_params).to eq(payload.deep_stringify_keys)
      else
        expect(controller.raw_params).to eq(payload)
      end
    end

    it 'sets params to a rails-friendly payload' do
      controller.deserialize_jsonapi!
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
      expected.deep_stringify_keys! if Rails::VERSION::MAJOR == 4
      expect(controller.params).to eq(expected)
    end
  end
end
