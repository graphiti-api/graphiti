require 'spec_helper'

RSpec.describe 'fields' do
  include_context 'resource testing'
  let(:resource) { Class.new(PORO::EmployeeResource) }
  let(:base_scope) { { type: :employees } }

  let!(:employee) do
    PORO::Employee.create(first_name: 'John', last_name: 'Doe')
  end

  subject(:attributes) { json['data'][0]['attributes'] }

  it 'does not limit without fields param' do
    render
    expect(attributes.keys).to eq(%w(first_name last_name age))
  end

  it 'limits to only the requested fields' do
    params[:fields] = { employees: 'first_name,last_name' }
    render
    expect(attributes.keys).to eq(%w(first_name last_name))
  end

  context 'when a field is guarded' do
    before do
      params[:fields] = { authors: 'first_name,salary' }
    end

    context 'and the guard does not pass' do
      let(:ctx) { double(current_user: 'non-admin').as_null_object }

      it 'does not render the field' do
        JsonapiCompliable.with_context ctx, {} do
          render
          expect(attributes.keys).to_not include('salary')
        end
      end
    end

    context 'and the guard passes' do
      let(:ctx) { double(current_user: 'admin').as_null_object }

      it 'renders the field' do
        JsonapiCompliable.with_context ctx, {} do
          render
          expect(attributes.keys).to include('salary')
        end
      end
    end
  end
end
