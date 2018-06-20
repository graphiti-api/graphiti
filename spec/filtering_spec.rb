require 'spec_helper'

RSpec.describe 'filtering' do
  include JsonHelpers
  include_context 'resource testing'
  let(:resource) { Class.new(PORO::EmployeeResource) }
  let(:base_scope) { { type: :employees, conditions: {} } }

  let!(:employee1) do
    PORO::Employee.create(first_name: 'Stephen', last_name: 'King')
  end
  let!(:employee2) do
    PORO::Employee.create(first_name: 'Agatha', last_name: 'Christie')
  end
  let!(:employee3) do
    PORO::Employee.create(first_name: 'William', last_name: 'Shakesphere')
  end
  let!(:employee4) do
    PORO::Employee.create(first_name: 'Harold',  last_name: 'Robbins')
  end

  it 'scopes correctly' do
    params[:filter] = { id: employee1.id }
    expect(records.map(&:id)).to eq([employee1.id])
  end

  context 'when filtering based on calling context' do
    around do |e|
      JsonapiCompliable.with_context(OpenStruct.new(runtime_id: employee3.id)) do
        e.run
      end
    end

    before do
      resource.attribute :foo, :boolean
      resource.filter :foo do |scope, value, ctx|
        scope[:conditions][:id] = ctx.runtime_id
        scope
      end
      params[:filter] = { foo: true }
    end

    it 'has access to calling context' do
      expect(records.map(&:id)).to eq([employee3.id])
    end
  end

  context 'when running an implicit attribute filter' do
    before do
      resource.attribute :active, :boolean
    end

    it 'works' do
      params[:filter] = { active: 'true' }
      [employee1, employee3, employee4].each do |e|
        e.update_attributes(active: true)
      end
      employee2.update_attributes(active: false)
      expect(records.map(&:id)).to eq([employee1.id, employee3.id, employee4.id])
    end
  end

  context 'when filter is a "string nil"' do
    before do
      params[:filter] = { first_name: 'nil' }
      PORO::DB.data
      employee2.update_attributes(first_name: nil)
    end

    it 'converts to a real nil' do
      ids = records.map(&:id)
      expect(ids).to eq([employee2.id])
    end
  end

  context 'when filter is a "string null"' do
    before do
      params[:filter] = { first_name: 'null' }
      employee2.update_attributes(first_name: nil)
    end

    it 'converts to a real nil' do
      ids = records.map(&:id)
      expect(ids).to eq([employee2.id])
    end
  end

  context 'when filter is a "string boolean"' do
    before do
      resource.attribute :active, :boolean
      params[:filter] = { active: 'true' }
      [employee1, employee3, employee4].each do |e|
        e.update_attributes(active: true)
      end
      employee2.update_attributes(active: false)
    end

    it 'automatically casts to a real boolean' do
      ids = records.map(&:id)
      expect(ids.length).to eq(3)
      expect(ids).to_not include(employee2.id)
    end

    context 'and multiple are passed' do
      before do
        params[:filter] = { active: 'true,false' }
      end

      it 'still works' do
        ids = records.map(&:id)
        expect(ids.length).to eq(4)
      end
    end
  end

  context 'when filter is an integer' do
    before do
      params[:filter] = { id: employee1.id }
    end

    it 'still works' do
      expect(records.map(&:id)).to eq([employee1.id])
    end
  end

  context 'when customized with alternate param name' do
    before do
      params[:filter] = { name: 'Stephen' }
    end

    xit 'filters based on the correct name' do
      expect(records.map(&:id)).to eq([employee1.id])
    end
  end

  context 'when the supplied value is comma-delimited' do
    before do
      params[:filter] = { id: [employee1.id, employee2.id].join(',') }
    end

    it 'parses into a ruby array' do
      expect(records.map(&:id)).to eq([employee1.id, employee2.id])
    end
  end

  context 'when a default filter' do
    before do
      resource.class_eval do
        default_filter :first_name do |scope|
          scope[:conditions].merge!(first_name: 'William')
          scope
        end
      end
    end

    it 'applies by default' do
      expect(records.map(&:id)).to eq([employee3.id])
    end

    it 'is overrideable' do
      params[:filter] = { first_name: 'Stephen' }
      expect(records.map(&:id)).to eq([employee1.id])
    end

    xit "is overrideable when overriding via an allowed filter's alias" do
      params[:filter] = { name: 'Stephen' }
      expect(records.map(&:id)).to eq([employee1.id])
    end

    context 'when accessing calling context' do
      before do
        resource.class_eval do
          default_filter :first_name do |scope, ctx|
            scope[:conditions].merge!(id: ctx.runtime_id)
            scope
          end
        end
      end

      it 'works' do
        ctx = double(runtime_id: employee3.id).as_null_object
        JsonapiCompliable.with_context(ctx, {}) do
          expect(records.map(&:id)).to eq([employee3.id])
        end
      end
    end
  end

  context 'when filtering on an unknown attribute' do
    before do
      params[:filter] = { foo: 'bar' }
    end

    it 'raises helpful error' do
      expect {
        records
      }.to raise_error(JsonapiCompliable::Errors::AttributeError, 'AnonymousResourceClass: Tried to filter on on attribute :foo, but could not find an attribute with that name.')
    end

    context 'but there is a corresponding extra attribute' do
      before do
        resource.extra_attribute :foo, :string
      end

      context 'but it is not filterable' do
        it 'raises helpful error' do
          expect {
            records
          }.to raise_error(JsonapiCompliable::Errors::AttributeError, 'AnonymousResourceClass: Tried to filter on on attribute :foo, but the attribute was marked :filterable => false.')
        end
      end

      context 'and it is filterable' do
        before do
          resource.extra_attribute :foo, :string, filterable: true
          resource.filter :foo do |scope, dir|
            scope[:conditions] = { id: employee3.id }
            scope
          end
        end

        it 'works' do
          expect(records.map(&:id)).to eq([employee3.id])
        end
      end
    end
  end

  context 'when filter is guarded' do
    before do
      resource.class_eval do
        attribute :first_name, :string, filterable: :admin?

        def admin?
          !!context.admin
        end
      end
      params[:filter] = { first_name: 'Agatha' }
    end

    context 'and the guard passes' do
      around do |e|
        JsonapiCompliable.with_context(OpenStruct.new(admin: true)) do
          e.run
        end
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end

    context 'and the guard fails' do
      around do |e|
        JsonapiCompliable.with_context(OpenStruct.new(admin: false)) do
          e.run
        end
      end

      it 'raises helpful error' do
        expect {
          records
        }.to raise_error(JsonapiCompliable::Errors::AttributeError, 'AnonymousResourceClass: Tried to filter on on attribute :first_name, but the guard :admin? did not pass.')
      end
    end
  end

  context 'when filter is required' do
    before do
      resource.attribute :first_name, :string, filterable: :required
    end

    context 'and given in the request' do
      before do
        params[:filter] = { first_name: 'Agatha' }
      end

      it 'works' do
        expect(records.map(&:id)).to eq([employee2.id])
      end
    end

    context 'but not given in request' do
      it 'raises error' do
        expect {
          records
        }.to raise_error(JsonapiCompliable::Errors::RequiredFilter)
      end
    end
  end

  context 'when > 1 filter required' do
    before do
      resource.attribute :first_name, :string, filterable: :required
      resource.attribute :last_name, :string, filterable: :required
    end

    context 'but not given in request' do
      it 'raises error that lists all unsupplied filters' do
        expect {
          records
        }.to raise_error(/The required filters "first_name, last_name"/)
      end
    end
  end
end
