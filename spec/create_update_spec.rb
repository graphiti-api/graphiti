require 'spec_helper'

RSpec.describe 'create/update', type: :controller do
  controller(ApplicationController) do
    jsonapi { }

    before_action :deserialize_jsonapi!, only: [:create, :update]

    def create
      author = Author.new(author_params.except(:state_attributes))
      author.state = State.find_or_initialize_by(author_params[:state_attributes])
      author.save!(validate: false)
      render_ams(author, scope: false)
    end

    def update
      author = Author.find(author_params[:id])
      author_params[:books_attributes].each do |attrs|
        book = Book.find_or_initialize_by(attrs)
        author.association(:books).add_to_target(book, :skip_callbacks)
      end
      author.association(:books).loaded!
      author.save!
      render_ams(author, scope: false)
    end

    private

    def author_params
      params.require(:author).permit!
    end
  end

  let!(:virginia) { State.create!(name: 'virginia') }

  context 'when creating' do
    it 'includes whatever nested relations were sent in the request in the response' do
      post :create, params: {
        data: {
          type: 'authors',
          attributes: { first_name: 'Stephen', last_name: 'King' },
          relationships: {
            state: {
              data: {
                type: 'states',
                id: virginia.id
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

      expect(json_included_types).to match_array(%w(states books))
      expect(json_include('states')['id']).to eq(virginia.id.to_s)
    end
  end

  context 'when updating' do
    let!(:author) { Author.create!(first_name: 'Stephen', last_name: 'King', state: virginia) }
    let!(:old_book) { author.books.create(title: "The Shining") }

    before do
      routes.draw { put "update" => "anonymous#update" }
    end

    it 'should include relations sent as part of payload' do
      put :update, id: author.id, params: {
        data: {
          id: author.id,
          type: 'authors',
          relationships: {
            books: {
              data: [
                {
                  type: 'books',
                  attributes: {
                    title: "The Firm"
                  }
                }
              ]
            }
          }
        }
      }

      expect(json_included_types).to match_array(%w(books))
      expect(json_includes('books').length).to eq(1)
      expect(json_include('books')['id']).to eq(Book.last.id.to_s)
      author.reload
      expect(author.book_ids).to match_array(Book.pluck(:id))
    end
  end
end
