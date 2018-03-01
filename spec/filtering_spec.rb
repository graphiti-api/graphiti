require 'spec_helper'

RSpec.describe 'filtering' do
  include_context 'scoping'

  before do
    resource_class.class_eval do
      allow_filter :id
      allow_filter :first_name, aliases: [:name]
      allow_filter :first_name_guarded, if: :can_filter_first_name? do |scope, value|
        scope.where(first_name: value)
      end
      allow_filter :first_name_prefix do |scope, value|
        scope.where(['first_name like ?', "#{value}%"])
      end
      allow_filter :active
      allow_filter :temp do |scope, value, ctx|
        scope.where(id: ctx.runtime_id)
      end
    end
  end

  let!(:author1) { Author.create!(first_name: 'Stephen', last_name: 'King') }
  let!(:author2) { Author.create!(first_name: 'Agatha', last_name: 'Christie') }
  let!(:author3) { Author.create!(first_name: 'William', last_name: 'Shakesphere') }
  let!(:author4) { Author.create!(first_name: 'Harold',  last_name: 'Robbins') }

  it 'scopes correctly' do
    params[:filter] = { id: author1.id }
    expect(scope.resolve.map(&:id)).to eq([author1.id])
  end

  # For example, getting current user from controller
  it 'has access to calling context' do
    ctx = double(runtime_id: author3.id).as_null_object
    JsonapiCompliable.with_context(ctx, {}) do
      params[:filter] = { temp: true }
      expect(scope.resolve.map(&:id)).to eq([author3.id])
    end
  end

  context 'when filter is a "string nil"' do
    before do
      params[:filter] = { first_name: 'nil' }
      author2.update_attribute(:first_name, nil)
    end

    it 'converts to a real nil' do
      ids = scope.resolve.map(&:id)
      expect(ids).to eq([author2.id])
    end
  end

  context 'when filter is a "string null"' do
    before do
      params[:filter] = { first_name: 'null' }
      author2.update_attribute(:first_name, nil)
    end

    it 'converts to a real nil' do
      ids = scope.resolve.map(&:id)
      expect(ids).to eq([author2.id])
    end
  end

  context 'when filter is a "string boolean"' do
    before do
      params[:filter] = { active: 'true' }
      author2.update_attribute(:active, false)
    end

    it 'automatically casts to a real boolean' do
      ids = scope.resolve.map(&:id)
      expect(ids.length).to eq(3)
      expect(ids).to_not include(author2.id)
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
      params[:filter] = { id: author1.id }
    end

    it 'still works' do
      expect(scope.resolve.map(&:id)).to eq([author1.id])
    end
  end

  context 'when customized with a block' do
    before do
      params[:filter] = { first_name_prefix: 'Ag' }
    end

    it 'scopes based on the given block' do
      expect(scope.resolve.map(&:id)).to eq([author2.id])
    end
  end

  context 'when customized with alternate param name' do
    before do
      params[:filter] = { name: 'Stephen' }
    end

    it 'filters based on the correct name' do
      expect(scope.resolve.map(&:id)).to eq([author1.id])
    end
  end

  context 'when the supplied value is comma-delimited' do
    before do
      params[:filter] = { id: [author1.id, author2.id].join(',') }
    end

    it 'parses into a ruby array' do
      expect(scope.resolve.map(&:id)).to eq([author1.id, author2.id])
    end
  end

  context 'when a default filter' do
    before do
      resource_class.class_eval do
        default_filter :first_name do |scope|
          scope.where(first_name: 'William')
        end
      end
    end

    it 'applies by default' do
      expect(scope.resolve.map(&:id)).to eq([author3.id])
    end

    it 'is overrideable' do
      params[:filter] = { first_name: 'Stephen' }
      expect(scope.resolve.map(&:id)).to eq([author1.id])
    end

    it "is overrideable when overriding via an allowed filter's alias" do
      params[:filter] = { name: 'Stephen' }
      expect(scope.resolve.map(&:id)).to eq([author1.id])
    end

    context 'when accessing calling context' do
      before do
        resource_class.class_eval do
          default_filter :first_name do |scope, ctx|
            scope.where(id: ctx.runtime_id)
          end
        end
      end

      it 'works' do
        ctx = double(runtime_id: author3.id).as_null_object
        JsonapiCompliable.with_context(ctx, {}) do
          expect(scope.resolve.map(&:id)).to eq([author3.id])
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
          expect(scope.resolve.map(&:id)).to eq([author1.id])
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
end
