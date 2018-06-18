require 'spec_helper'

RSpec.describe JsonapiCompliable::Query do
  let(:resource_class) { Class.new(PORO::EmployeeResource) }
  let(:resource) { resource_class.new }
  let(:params)   { { include: 'positions' } }
  let(:instance) { described_class.new(resource, params) }

  describe '#to_hash' do
    subject { instance.to_hash }

    describe 'filters' do
      it 'defaults main entity' do
        expect(subject[:employees][:filter]).to eq({})
      end

      it 'does not default associations' do
        expect(subject[:employees][:filter]).to eq({})
      end

      context 'when association is not requested' do
        before do
          params.delete(:include)
        end

        it 'does not default the association query' do
          expect(subject).to_not have_key(:positions)
        end
      end

      context 'when filter param present' do
        before do
          params[:filter] = { id: 1, positions: { title: 'foo' } }
        end

        it 'applies to main entity' do
          expect(subject[:employees][:filter]).to eq({ id: 1 })
        end

        it 'applies to associations' do
          expect(subject[:positions][:filter]).to eq({ title: 'foo' })
        end

        context 'as a string' do
          before do
            params[:filter] = { 'id' => 1 }
          end

          it 'stringifies' do
            expect(subject[:employees][:filter]).to eq({ id: 1 })
          end
        end
      end
    end

    describe 'fields' do
      it 'defaults main entity' do
        expect(subject[:employees][:fields]).to eq({})
      end

      it 'defaults associations' do
        expect(subject[:positions][:fields]).to eq({})
      end

      context 'when fields param' do
        before do
          params[:fields] = {
            employees: 'first_name,last_name',
            positions: 'title'
          }
        end

        it 'applies to main entity' do
          expect(subject[:employees][:fields])
            .to eq(employees: [:first_name, :last_name], positions: [:title])
        end

        it 'applies to associations' do
          expect(subject[:positions][:fields])
            .to eq(employees: [:first_name, :last_name], positions: [:title])
        end
      end
    end

    describe 'extra_fields' do
      it 'defaults main entity' do
        expect(subject[:employees][:extra_fields]).to eq({})
      end

      it 'defaults associations' do
        expect(subject[:employees][:extra_fields]).to eq({})
      end

      context 'when extra_fields param' do
        before do
          params[:extra_fields] = {
            employees: 'foo,bar',
            positions: 'baz'
          }
        end

        it 'applies to main entity' do
          expect(subject[:employees][:extra_fields])
            .to eq(employees: [:foo, :bar], positions: [:baz])
        end

        it 'applies to associations' do
          expect(subject[:positions][:extra_fields])
            .to eq(employees: [:foo, :bar], positions: [:baz])
        end
      end
    end

    describe 'sort' do
      it 'defaults main entity' do
        expect(subject[:employees][:sort]).to eq([])
      end

      it 'defaults associations' do
        expect(subject[:employees][:sort]).to eq([])
      end

      context 'when sort param' do
        before do
          params[:sort] = 'employees.first_name,-employees.last_name,positions.title'
        end

        it 'applies to main entity' do
          expect(subject[:employees][:sort])
            .to eq([{ first_name: :asc }, { last_name: :desc }])
        end

        it 'applies to associations' do
          expect(subject[:positions][:sort])
            .to eq([{ title: :asc }])
        end

        context 'when no type prefix' do
          before do
            params[:sort] = '-first_name'
          end

          it 'applies to main entity' do
            expect(subject[:employees][:sort])
              .to eq([{ first_name: :desc }])
          end
        end
      end
    end

    describe 'pagination' do
      it 'defaults main entity' do
        expect(subject[:employees][:page]).to eq({})
      end

      it 'defaults associations' do
        expect(subject[:positions][:page]).to eq({})
      end

      context 'when pagination param' do
        before do
          params[:page] = { size: 10, number: 2, positions: { size: 5, number: 3 } }
        end

        it 'applies to main entity' do
          expect(subject[:employees][:page]).to eq(size: 10, number: 2)
        end

        it 'applies to associations' do
          expect(subject[:positions][:page]).to eq(size: 5, number: 3)
        end
      end
    end

    describe 'include' do
      before do
        params[:include] = 'positions.department,positions.foo'
      end

      it 'sets main entity' do
        expect(subject[:employees][:include])
          .to eq(positions: { department: {}, foo: {} })
      end

      it 'sets associations' do
        positions_include = subject[:positions][:include]
        expected = { department: {}, foo: {} }
        expect(positions_include).to eq(expected)
      end

      it 'excludes relations not in the whitelist' do
        params[:include] = 'positions.department,positions.foo'
        ctx = double sideload_whitelist: {
          index: { positions: { department: {} } }
        }

        resource.with_context ctx, :index do
          expect(subject[:employees][:include])
            .to eq(positions: { department: {} })
          expect(subject[:positions][:include]).to eq(department: {})
        end
      end

      context 'when include param present' do
        before do
          params[:include] = 'positions.department.foo,bio'
        end

        it 'transforms to hash' do
          expect(subject[:employees][:include]).to eq({
            positions: { department: { foo: {} } },
            bio: {}
          })
          expect(subject[:positions][:include]).to eq({
            department: { foo: {} }
          })
          expect(subject[:department][:include]).to eq({
            foo: {}
          })
          expect(subject[:foo][:include]).to eq({})
          expect(subject[:bio][:include]).to eq({})
        end
      end
    end

    describe 'stats' do
      it 'defaults main entity' do
        expect(subject[:employees][:stats]).to eq({})
      end

      it 'defaults associations' do
        expect(subject[:positions][:stats]).to eq({})
      end
    end

    context 'when stats param present' do
      before do
        params[:stats] = {
          employees: {
            total: 'count,sum',
            stddev: 'amount'
          },
          positions: {
            foo: 'bar'
          }
        }
      end

      it 'applies to main entity' do
        expect(subject[:employees][:stats]).to eq({
          total: [:count, :sum],
          stddev: [:amount]
        })
      end

      it 'applies to associations' do
        expect(subject[:positions][:stats]).to eq({
          foo: [:bar]
        })
      end

      context 'when no type prefix' do
        before do
          params[:stats] = { total: 'count,sum', stddev: 'amount' }
        end

        it 'applies to main entity' do
          expect(subject[:employees][:stats]).to eq({
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
