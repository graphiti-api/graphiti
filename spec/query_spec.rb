require 'spec_helper'

RSpec.describe JsonapiCompliable::Query do
  let(:resource_class) do
    Class.new(JsonapiCompliable::Resource) do
      type :authors

      allow_sideload :books do
        allow_sideload :genre do
          allow_sideload :owner
        end
        allow_sideload :publisher
      end
      allow_sideload :state
    end
  end

  let(:resource) { resource_class.new }
  let(:params)   { { include: 'books' } }
  let(:instance) { described_class.new(resource, params) }

  describe '#to_hash' do
    subject { instance.to_hash }

    describe 'filters' do
      it 'defaults main entity' do
        expect(subject[:authors][:filter]).to eq({})
      end

      it 'does not default associations' do
        expect(subject[:books][:filter]).to eq({})
      end

      context 'when association is not requested' do
        before do
          params.delete(:include)
        end

        it 'does not default the association query' do
          expect(subject).to_not have_key(:books)
        end
      end

      context 'when filter param present' do
        before do
          params[:filter] = { id: 1, books: { title: 'foo' } }
        end

        it 'applies to main entity' do
          expect(subject[:authors][:filter]).to eq({ id: 1 })
        end

        it 'applies to associations' do
          expect(subject[:books][:filter]).to eq({ title: 'foo' })
        end

        context 'as a string' do
          before do
            params[:filter] = { 'id' => 1 }
          end

          it 'stringifies' do
            expect(subject[:authors][:filter]).to eq({ id: 1 })
          end
        end
      end
    end

    describe 'fields' do
      it 'defaults main entity' do
        expect(subject[:authors][:fields]).to eq({})
      end

      it 'defaults associations' do
        expect(subject[:books][:fields]).to eq({})
      end

      context 'when fields param' do
        before do
          params[:fields] = { authors: 'first_name,last_name', books: 'title' }
        end

        it 'applies to main entity' do
          expect(subject[:authors][:fields])
            .to eq(authors: [:first_name, :last_name], books: [:title])
        end

        it 'applies to associations' do
          expect(subject[:books][:fields])
            .to eq(authors: [:first_name, :last_name], books: [:title])
        end
      end
    end

    describe 'extra_fields' do
      it 'defaults main entity' do
        expect(subject[:authors][:extra_fields]).to eq({})
      end

      it 'defaults associations' do
        expect(subject[:books][:extra_fields]).to eq({})
      end

      context 'when extra_fields param' do
        before do
          params[:extra_fields] = { authors: 'first_name,last_name', books: 'title' }
        end

        it 'applies to main entity' do
          expect(subject[:authors][:extra_fields])
            .to eq(authors: [:first_name, :last_name], books: [:title])
        end

        it 'applies to associations' do
          expect(subject[:books][:extra_fields])
            .to eq(authors: [:first_name, :last_name], books: [:title])
        end
      end
    end

    describe 'sort' do
      it 'defaults main entity' do
        expect(subject[:authors][:sort]).to eq([])
      end

      it 'defaults associations' do
        expect(subject[:books][:sort]).to eq([])
      end

      context 'when sort param' do
        before do
          params[:sort] = 'authors.first_name,-authors.last_name,books.title'
        end

        it 'applies to main entity' do
          expect(subject[:authors][:sort])
            .to eq([{ first_name: :asc }, { last_name: :desc }])
        end

        it 'applies to associations' do
          expect(subject[:books][:sort])
            .to eq([{ title: :asc }])
        end

        context 'when no type prefix' do
          before do
            params[:sort] = '-first_name'
          end

          it 'applies to main entity' do
            expect(subject[:authors][:sort])
              .to eq([{ first_name: :desc }])
          end
        end
      end
    end

    describe 'pagination' do
      it 'defaults main entity' do
        expect(subject[:authors][:page]).to eq({})
      end

      it 'defaults associations' do
        expect(subject[:books][:page]).to eq({})
      end

      context 'when pagination param' do
        before do
          params[:page] = { size: 10, number: 2, books: { size: 5, number: 3 } }
        end

        it 'applies to main entity' do
          expect(subject[:authors][:page]).to eq(size: 10, number: 2)
        end

        it 'applies to associations' do
          expect(subject[:books][:page]).to eq(size: 5, number: 3)
        end
      end
    end

    describe 'include' do
      before do
        params[:include] = 'books.genre,books.publisher'
      end

      it 'sets main entity' do
        expect(subject[:authors][:include])
          .to eq(books: { genre: {}, publisher: {} })
      end

      it 'sets associations' do
        books_include = subject[:books][:include]
        expected = { genre: {}, publisher: {} }
        expect(books_include).to eq(expected)
      end

      it 'excludes relations not in the whitelist' do
        params[:include] = 'books.genre,books.publisher'
        ctx = double(sideload_whitelist: { index: { books: { genre: {} } } })

        resource.with_context ctx, :index do
          expect(subject[:authors][:include]).to eq(books: { genre: {} })
          expect(subject[:books][:include]).to eq(genre: {})
        end
      end

      context 'when include param present' do
        before do
          params[:include] = 'books.genre.owner,state'
        end

        it 'transforms to hash' do
          expect(subject[:authors][:include]).to eq({
            books: { genre: { owner: {} } },
            state: {}
          })
          expect(subject[:books][:include]).to eq({
            genre: { owner: {} }
          })
          expect(subject[:genre][:include]).to eq({
            owner: {}
          })
          expect(subject[:owner][:include]).to eq({})
          expect(subject[:state][:include]).to eq({})
        end
      end
    end

    describe 'stats' do
      it 'defaults main entity' do
        expect(subject[:authors][:stats]).to eq({})
      end

      it 'defaults associations' do
        expect(subject[:books][:stats]).to eq({})
      end
    end

    context 'when stats param present' do
      before do
        params[:stats] = {
          authors: {
            total: 'count,sum',
            stddev: 'amount'
          },
          books: {
            foo: 'bar'
          }
        }
      end

      it 'applies to main entity' do
        expect(subject[:authors][:stats]).to eq({
          total: [:count, :sum],
          stddev: [:amount]
        })
      end

      it 'applies to associations' do
        expect(subject[:books][:stats]).to eq({
          foo: [:bar]
        })
      end

      context 'when no type prefix' do
        before do
          params[:stats] = { total: 'count,sum', stddev: 'amount' }
        end

        it 'applies to main entity' do
          expect(subject[:authors][:stats]).to eq({
            total: [:count, :sum],
            stddev: [:amount]
          })
        end
      end
    end
  end

  describe '#zero_results?' do
    subject { instance.zero_results? }

    context 'when no pagination' do
      it { is_expected.to eq(false) }
    end

    context 'with positive page size' do
      before do
        params[:page] = { size: '2' }
      end

      it { is_expected.to eq(false) }
    end

    context 'with page size "0" string' do
      before do
        params[:page] = { size: '0' }
      end

      it { is_expected.to eq(true) }
    end

    context 'with page size 0 integer' do
      before do
        params[:page] = { size: 0 }
      end

      it { is_expected.to eq(true) }
    end
  end
end
