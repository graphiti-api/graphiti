require 'spec_helper'

RSpec.describe 'filtering' do
  include JsonHelpers
  include_context 'resource testing'
  let(:resource) { Class.new(PORO::EmployeeResource).new }
  let(:base_scope) { { type: :employees, conditions: {} } }

  before do
    resource.class.class_eval do
      allow_filter :id
      allow_filter :first_name, aliases: [:name]
      allow_filter :first_name_guarded, if: :can_filter_first_name? do |scope, value|
        scope[:conditions].merge!(first_name: value)
        scope
      end
      allow_filter :active
      allow_filter :temp do |scope, value, ctx|
        scope[:conditions].merge!(id: ctx.runtime_id)
        scope
      end
    end
  end

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
    expect(scope.resolve.map(&:id)).to eq([employee1.id])
  end

  # For example, getting current user from controller
  it 'has access to calling context' do
    ctx = double(runtime_id: employee3.id).as_null_object
    JsonapiCompliable.with_context(ctx, {}) do
      params[:filter] = { temp: true }
      expect(scope.resolve.map(&:id)).to eq([employee3.id])
    end
  end

  context 'when filter is a "string nil"' do
    before do
      params[:filter] = { first_name: 'nil' }
      PORO::DB.data
      employee2.update_attributes(first_name: nil)
    end

    it 'converts to a real nil' do
      ids = scope.resolve.map(&:id)
      expect(ids).to eq([employee2.id])
    end
  end

  context 'when filter is a "string null"' do
    before do
      params[:filter] = { first_name: 'null' }
      employee2.update_attributes(first_name: nil)
    end

    it 'converts to a real nil' do
      ids = scope.resolve.map(&:id)
      expect(ids).to eq([employee2.id])
    end
  end

  context 'when filter is a "string boolean"' do
    before do
      params[:filter] = { active: 'true' }
      [employee1, employee3, employee4].each do |e|
        e.update_attributes(active: true)
      end
      employee2.update_attributes(active: false)
    end

    it 'automatically casts to a real boolean' do
      ids = scope.resolve.map(&:id)
      expect(ids.length).to eq(3)
      expect(ids).to_not include(employee2.id)
    end

    context 'and multiple are passed' do
      before do
        params[:filter] = { active: 'true,false' }
      end

      it 'still works' do
        ids = scope.resolve.map(&:id)
        expect(ids.length).to eq(4)
      end
    end
  end

  context 'when filter is an integer' do
    before do
      params[:filter] = { id: employee1.id }
    end

    it 'still works' do
      expect(scope.resolve.map(&:id)).to eq([employee1.id])
    end
  end

  context 'when customized with alternate param name' do
    before do
      params[:filter] = { name: 'Stephen' }
    end

    it 'filters based on the correct name' do
      expect(scope.resolve.map(&:id)).to eq([employee1.id])
    end
  end

  context 'when the supplied value is comma-delimited' do
    before do
      params[:filter] = { id: [employee1.id, employee2.id].join(',') }
    end

    it 'parses into a ruby array' do
      expect(scope.resolve.map(&:id)).to eq([employee1.id, employee2.id])
    end
  end

  context 'when a default filter' do
    before do
      resource.class.class_eval do
        default_filter :first_name do |scope|
          scope[:conditions].merge!(first_name: 'William')
          scope
        end
      end
    end

    it 'applies by default' do
      expect(scope.resolve.map(&:id)).to eq([employee3.id])
    end

    it 'is overrideable' do
      params[:filter] = { first_name: 'Stephen' }
      expect(scope.resolve.map(&:id)).to eq([employee1.id])
    end

    it "is overrideable when overriding via an allowed filter's alias" do
      params[:filter] = { name: 'Stephen' }
      expect(scope.resolve.map(&:id)).to eq([employee1.id])
    end

    context 'when accessing calling context' do
      before do
        resource.class.class_eval do
          default_filter :first_name do |scope, ctx|
            scope[:conditions].merge!(id: ctx.runtime_id)
            scope
          end
        end
      end

      it 'works' do
        ctx = double(runtime_id: employee3.id).as_null_object
        JsonapiCompliable.with_context(ctx, {}) do
          expect(scope.resolve.map(&:id)).to eq([employee3.id])
        end
      end
    end
  end

  context 'when the filter is guarded' do
    let(:can_filter) { true }
    let(:ctx) { double(can_filter_first_name?: can_filter).as_null_object }

    before do
      params[:filter] = { first_name_guarded: 'Stephen' }
    end

    context 'and the guard passes' do
      it 'filters normally' do
        resource.with_context ctx do
          expect(scope.resolve.map(&:id)).to eq([employee1.id])
        end
      end
    end

    context 'and the guard does not pass' do
      let(:can_filter) { false }

      it 'raises an error' do
        expect {
          resource.with_context ctx do
            scope.resolve
          end
        }.to raise_error(JsonapiCompliable::Errors::BadFilter)
      end
    end
  end

  context 'when the filter is not whitelisted' do
    before do
      params[:filter] = { foo: 'bar' }
    end

    it 'raises an error' do
      expect {
        scope.resolve
      }.to raise_error(JsonapiCompliable::Errors::BadFilter)
    end
  end

  context 'when one or more filters are required' do
    before do
      employee = employee1
      resource.class.class_eval do
        allow_filter :required, required: true do |scope, value|
          scope[:conditions].merge!(id: employee.id)
          scope
        end

        allow_filter :also_required, required: true do |scope, value|
          scope[:conditions].merge!(first_name: employee.first_name)
          scope
        end
      end
    end

    context 'and all required filter are provided' do
      before do
        params[:filter] = { required: true, also_required: true }
      end

      it 'should return results' do
        ids = scope.resolve.map(&:id)
        expect(ids).to eq([employee1.id])
      end
    end

    context 'and at least one required filter is provided but some are missing' do
      before do
        params[:filter] = { required: true }
      end

      it 'raises an error' do
        expect {
          scope.resolve
        }.to raise_error(JsonapiCompliable::Errors::RequiredFilter, 'The required filter "also_required" was not provided')
      end
    end

    context 'and no required filters are provided' do
      before do
        params[:filter] = { }
      end

      it 'raises an error' do
        expect {
          scope.resolve
        }.to raise_error(JsonapiCompliable::Errors::RequiredFilter, 'The required filters "required, also_required" were not provided')
      end
    end

    context 'and required filter determined by proc' do
      context 'when required proc evaluates to true' do
        before do
          resource.class.class_eval do
            allow_filter :required_by_proc, required: Proc.new{|ctx| true} do |scope, value|
              scope[:conditions].merge!(first_name: employee1.first_name)
              scope
            end
          end

          params[:filter] = { required: true, also_required: true }
        end

        it 'raises an error' do
          expect {
            scope.resolve
          }.to raise_error(JsonapiCompliable::Errors::RequiredFilter, 'The required filter "required_by_proc" was not provided')
        end
      end

      context 'when required proc evaluates to false' do
        before do
          resource.class.class_eval do
            allow_filter :required_by_proc, required: Proc.new{|ctx| false} do |scope, value|
              scope[:conditions].merge!(first_name: employee1.first_name)
              scope
            end
          end

          params[:filter] = { required: true, also_required: true }
        end

        it 'should not be required' do
          ids = scope.resolve.map(&:id)
          expect(ids).to eq([employee1.id])
        end
      end
    end
  end
end
