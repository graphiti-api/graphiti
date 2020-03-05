require "spec_helper"

RSpec.describe Graphiti::Sideload do
  let(:parent_resource_class) do
    Class.new(PORO::EmployeeResource) do
      def self.name
        "PORO::EmployeeResource"
      end
    end
  end
  let(:resource_class) do
    Class.new(PORO::PositionResource) do
      self.model = PORO::Position
      def self.name
        "PORO::PositionResource"
      end
    end
  end
  let(:opts) do
    {
      type: :has_many,
      parent_resource: parent_resource_class,
      resource: resource_class
    }
  end
  let(:name) { :foo }
  let(:instance) { Class.new(described_class).new(name, opts) }

  context "when passed both :remote and :resource options" do
    before do
      opts[:remote] = "asdf"
    end

    it "raises error" do
      expect {
        instance
      }.to raise_error(Graphiti::Errors::SideloadConfig)
    end
  end

  context "when passed both :remote and :link options" do
    before do
      opts[:remote] = "asdf"
      opts[:link] = true
    end

    it "raises error" do
      expect {
        instance
      }.to raise_error(Graphiti::Errors::SideloadConfig)
    end
  end

  describe "reading and writing" do
    context "with booleans" do
      it "works" do
        instance = Class.new(described_class).new(name, opts.merge(readable: true, writable: true))
        expect(instance).to be_readable
        expect(instance).to be_writable

        instance = Class.new(described_class).new(name, opts.merge(readable: false, writable: false))
        expect(instance).not_to be_readable
        expect(instance).not_to be_writable
      end
    end

    context "with symbols and stings" do
      let(:resource_class) do
        Class.new(PORO::PositionResource) do
          self.model = PORO::Position
          def self.name
            "PORO::PositionResource"
          end

          def user_can_read?
            false
          end

          def user_can_write?
            true
          end
        end
      end

      it "works with symbols" do
        instance = Class.new(described_class).new(name, opts.merge(readable: :user_can_read?, writable: :user_can_write?))
        expect(instance).not_to be_readable
        expect(instance).to be_writable
      end

      it "works with strings" do
        instance = Class.new(described_class).new(name, opts.merge(readable: "user_can_read?", writable: "user_can_write?"))
        expect(instance).not_to be_readable
        expect(instance).to be_writable
      end
    end

    context "with procs" do
      let(:resource_class) do
        Class.new(PORO::PositionResource) do
          self.model = PORO::Position
          def self.name
            "PORO::PositionResource"
          end

          def user_can_read?
            false
          end

          def user_can_write?
            true
          end
        end
      end

      it "works" do
        options = opts.merge(readable: lambda { user_can_read? }, writable: lambda { true })
        instance = Class.new(described_class).new(name, options)
        expect(instance).not_to be_readable
        expect(instance).to be_writable
      end
    end
  end

  describe "#primary_key" do
    it "defaults to id" do
      expect(instance.primary_key).to eq(:id)
    end

    context "when passed in constructor" do
      before do
        opts[:primary_key] = :foo
      end

      it "is used" do
        expect(instance.primary_key).to eq(:foo)
      end
    end
  end

  describe "#foreign_key" do
    it "is inferred by default" do
      expect(instance).to receive(:infer_foreign_key) { :foo_id }
      expect(instance.foreign_key).to eq(:foo_id)
    end

    context "when passed in constructor" do
      before do
        opts[:foreign_key] = :bar_id
      end

      it "is used" do
        expect(instance.foreign_key).to eq(:bar_id)
      end
    end
  end

  describe "#resource_class" do
    let(:name) { :positions }

    before do
      opts.delete(:resource)
    end

    it "is inferred by default" do
      expect(instance.resource_class).to eq(PORO::PositionResource)
    end

    context "when no class in that namespace" do
      before do
        stub_const("PositionResource", PORO::PositionResource)
        hide_const("PORO::PositionResource")
      end

      it "falls back to non-namespaced" do
        expect(instance.resource_class).to eq(PositionResource)
      end
    end

    context "when not found by inferrence" do
      let(:name) { :foo }

      it "raises helpful error" do
        expect {
          instance.resource_class
        }.to raise_error(Graphiti::Errors::ResourceNotFound)
      end
    end

    context "when passed in constructor" do
      before do
        opts[:resource] = PORO::EmployeeResource
      end

      it "is used" do
        expect(instance.resource_class).to eq(PORO::EmployeeResource)
      end
    end
  end

  describe "#base_scope" do
    it "falls back to the resource default" do
      expect(instance.base_scope).to eq(type: :positions)
    end

    context "when passed in constructor" do
      before do
        opts[:base_scope] = "bar"
      end

      it "is used" do
        expect(instance.base_scope).to eq("bar")
      end

      context "as a proc" do
        before do
          opts[:base_scope] = -> { "procd" }
        end

        it "is executed" do
          expect(instance.base_scope).to eq("procd")
        end
      end
    end
  end

  describe "#type" do
    before do
      opts.delete(:type)
    end

    it "raises helpful error for subclass" do
      expect { instance.type }.to raise_error(/Override/)
    end

    context "when passed in constructor" do
      before do
        opts[:type] = :foo_type
      end

      it "is used" do
        expect(instance.type).to eq(:foo_type)
      end
    end
  end

  # Infers a to_many key; override for belongs_to
  describe "#infer_foreign_key" do
    context "when within module" do
      let(:name) { "positions" }

      module SideloadSpec
        class Employee
        end
      end

      before do
        opts[:parent_resource] = Class.new(Graphiti::Resource)
        opts[:parent_resource].model = SideloadSpec::Employee
      end

      it "derives a to_many foreign key from the resource model" do
        expect(instance.infer_foreign_key).to eq(:employee_id)
      end
    end

    context "when not within module" do
      let(:name) { "positions" }

      class SideloadSpecEmployee
      end

      before do
        opts[:parent_resource] = Class.new(Graphiti::Resource)
        opts[:parent_resource].model = SideloadSpecEmployee
      end

      it "derives a to_many foreign key from the resource model" do
        expect(instance.infer_foreign_key).to eq(:sideload_spec_employee_id)
      end
    end

    context "when the resource is remote" do
      let(:name) { "positions" }

      context "via the sideload :remote option" do
        it "is inferred correctly from the parent resource" do
          opts.delete(:resource)
          opts[:remote] = "http://foo.com/positions"
          expect(instance.infer_foreign_key).to eq(:employee_id)
        end

        context "and belongs_to" do
          let(:instance) { Class.new(Graphiti::Sideload::BelongsTo).new(name, opts) }

          before do
            opts[:type] = :belongs_to
          end

          it "works" do
            opts.delete(:resource)
            opts[:remote] = "http://foo.com/positions"
            expect(instance.infer_foreign_key).to eq(:position_id)
          end
        end
      end

      context "via resource class" do
        before do
          opts[:resource] = Class.new(Graphiti::Resource) do
            self.remote = "http://foo.com"
            def self.name
              "PORO::PositionResource"
            end
          end
        end

        it "is inferred correctly from the parent resource" do
          expect(instance.infer_foreign_key).to eq(:employee_id)
        end

        context "and belongs_to" do
          let(:instance) { Class.new(Graphiti::Sideload::BelongsTo).new(name, opts) }

          before do
            opts[:type] = :belongs_to
          end

          it "works" do
            expect(instance.infer_foreign_key).to eq(:position_id)
          end
        end
      end
    end
  end

  describe "#ids_for_parents" do
    let(:parent1) { double(id: 11) }
    let(:parent2) { double(id: 22) }
    let(:parents) { [parent1, parent2] }

    subject(:ids) { instance.ids_for_parents(parents) }

    it "maps over the primary key" do
      expect(ids).to eq([11, 22])
    end

    it "does not return duplicates" do
      parents << double(id: 22)
      expect(ids).to eq([11, 22])
    end

    it "does not return nils" do
      parents << double(id: nil)
      expect(ids).to eq([11, 22])
    end

    context "with custom primary key" do
      let(:parents) { [double(foo: 44), double(foo: 55)] }

      before do
        opts[:primary_key] = :foo
      end

      it "still works" do
        expect(ids).to eq([44, 55])
      end
    end
  end

  # parent_resource.associate_all(parent, children, association_name, type)
  describe "#associate_all" do
    before do
      opts[:type] = :has_many
    end

    it "delegates to parent resource" do
      parent, children = "a", ["b", "c"]
      expect(instance.parent_resource).to receive(:associate_all)
        .with(parent, children, :foo, :has_many)
      instance.associate_all(parent, children)
    end

    context "when given the :as option" do
      before do
        opts[:as] = :bar
      end

      it "is passed as the association name" do
        parent, children = "a", ["b", "c"]
        expect(instance.parent_resource).to receive(:associate)
          .with(parent, children, :bar, :has_many)
        instance.associate(parent, children)
      end
    end
  end

  describe "#associate" do
    before do
      opts[:type] = :has_many
    end

    it "delegates to parent resource" do
      parent, child = "a", "b"
      expect(instance.parent_resource).to receive(:associate)
        .with(parent, child, :foo, :has_many)
      instance.associate(parent, child)
    end

    context "when given the :as option" do
      before do
        opts[:as] = :bar
      end

      it "is passed as the association name" do
        parent, child = "a", "b"
        expect(instance.parent_resource).to receive(:associate)
          .with(parent, child, :bar, :has_many)
        instance.associate(parent, child)
      end
    end
  end

  describe "#disassociate" do
    before do
      opts[:type] = :has_many
    end

    it "delegates to parent resource" do
      parent, child = "a", "b"
      expect(instance.parent_resource).to receive(:disassociate)
        .with(parent, child, :foo, :has_many)
      instance.disassociate(parent, child)
    end

    context "when given the :as option" do
      before do
        opts[:as] = :bar
      end

      it "is passed as the association name" do
        parent, child = "a", "b"
        expect(instance.parent_resource).to receive(:disassociate)
          .with(parent, child, :bar, :has_many)
        instance.disassociate(parent, child)
      end
    end
  end

  describe "#assign" do
    context "when a to-many relationship" do
      let(:instance) { Graphiti::Sideload::HasMany.new(:positions, opts) }

      let(:employees) do
        [
          PORO::Employee.new(id: 1),
          PORO::Employee.new(id: 2)
        ]
      end

      let(:positions) do
        [
          PORO::Position.new(id: 1, employee_id: 1),
          PORO::Position.new(id: 2, employee_id: 1),
          PORO::Position.new(id: 3, employee_id: 2)
        ]
      end

      it "associates parents and children" do # awwww
        instance.assign(employees, positions)
        expect(employees[0].positions).to eq(positions[0..1])
        expect(employees[1].positions).to eq([positions.last])
      end

      context "when match, but parent is integer and child is string" do
        let(:positions) do
          [
            PORO::Position.new(id: 1, employee_id: "1"),
            PORO::Position.new(id: 2, employee_id: "1"),
            PORO::Position.new(id: 3, employee_id: "2")
          ]
        end

        it "still works" do
          instance.assign(employees, positions)
          expect(employees[0].positions).to eq(positions[0..1])
          expect(employees[1].positions).to eq([positions.last])
        end
      end

      context "when match, but parent is string and child is integer" do
        let(:employees) do
          [
            PORO::Employee.new(id: "1"),
            PORO::Employee.new(id: "2")
          ]
        end

        it "still works" do
          instance.assign(employees, positions)
          expect(employees[0].positions).to eq(positions[0..1])
          expect(employees[1].positions).to eq([positions.last])
        end
      end
    end

    context "when a to-one relationship" do
      before do
        opts.delete(:resource)
      end

      let(:parent_resource_class) { PORO::PositionResource }
      let(:instance) { Graphiti::Sideload::BelongsTo.new(:department, opts) }

      let(:positions) do
        [
          PORO::Position.new(id: 1, department_id: 1),
          PORO::Position.new(id: 2, department_id: 2)
        ]
      end

      let(:departments) do
        [
          PORO::Department.new(id: 1),
          PORO::Department.new(id: 2)
        ]
      end

      it "associates parents and children" do # awwww
        instance.assign(positions, departments)
        expect(positions[0].department).to eq(departments[0])
        expect(positions[1].department).to eq(departments[1])
      end

      context "when match, but parent is integer and child is string" do
        let(:departments) do
          [
            PORO::Department.new(id: "1"),
            PORO::Department.new(id: "2")
          ]
        end

        it "still works" do
          instance.assign(positions, departments)
          expect(positions[0].department).to eq(departments[0])
          expect(positions[1].department).to eq(departments[1])
        end
      end

      context "when match, but child is string and parent is integer" do
        let(:positions) do
          [
            PORO::Position.new(id: 1, department_id: "1"),
            PORO::Position.new(id: 2, department_id: "2")
          ]
        end

        it "still works" do
          instance.assign(positions, departments)
          expect(positions[0].department).to eq(departments[0])
          expect(positions[1].department).to eq(departments[1])
        end
      end
    end
  end

  describe ".params" do
    before do
      instance.class.params do |hash, parents, context|
        hash[:parents] = parents
        hash[:context] = context
      end
    end

    it "sets params proc" do
      hash, parents, context = {}, [double("parent")], double("context")
      instance.params_proc.call(hash, parents, context)
      expect(hash).to eq(parents: parents, context: context)
    end
  end

  describe ".pre_load" do
    before do
      instance.class.pre_load do |proxy|
        proxy[:foo] = "bar"
      end
    end

    it "sets pre_load proc" do
      hash = {}
      instance.pre_load_proc.call(hash)
      expect(hash).to eq(foo: "bar")
    end
  end

  describe "#association_name" do
    it "defaults to name" do
      expect(instance.association_name).to eq(:foo)
    end

    context "when given :as option" do
      before do
        opts[:as] = :bar
      end

      it "uses the option" do
        expect(instance.association_name).to eq(:bar)
      end
    end
  end

  describe "#load" do
    let(:params) { {} }
    let(:query) { Graphiti::Query.new(instance.resource, params) }
    let(:parents) { [double, double] }
    let(:results) { [double("result")] }

    before do
      allow(instance).to receive(:load_params) { {foo: "bar"} }
      allow(resource_class).to receive(:_all) { results }
    end

    it "uses base scope" do
      base = double
      allow(instance).to receive(:base_scope) { base }
      expect(resource_class).to receive(:_all)
        .with(anything, anything, base)
      instance.load(parents, query, nil)
    end

    it "uses load params" do
      expect(resource_class).to receive(:_all)
        .with({foo: "bar"}, anything, {type: :positions})
      instance.load(parents, query, nil)
    end

    it "passes internal load options" do
      expected = {
        default_paginate: false,
        sideload_parent_length: 2,
        parent: "parent",
        sideload: instance,
        query: anything,
        after_resolve: anything
      }
      expect(resource_class).to receive(:_all)
        .with(anything, expected, {type: :positions})
      instance.load(parents, query, "parent")
    end

    it "returns records" do
      records = instance.load(parents, query, nil)
      expect(records).to eq(results)
    end

    context "when params customization" do
      before do
        instance.class.params do |hash, parents, context|
          hash[:a] = parents
          hash[:b] = context.current_user
        end
      end

      it "is respected" do
        current_user = double
        expected = {
          foo: "bar",
          a: parents,
          b: current_user
        }
        expect(resource_class).to receive(:_all)
          .with(expected, anything, {type: :positions})

        Graphiti.with_context(OpenStruct.new(current_user: current_user)) do
          instance.load(parents, query, nil)
        end
      end
    end

    context "when pre_load customization" do
      let(:parents) { [] }

      before do
        params[:sort] = "-id"
        allow(resource_class).to receive(:_all).and_call_original
        allow(instance).to receive(:performant_assign?) { false }
        instance.class.pre_load do |proxy, parents|
          proxy.scope.object[:modified] = true
          proxy.scope.object[:parents] = parents
        end
      end

      it "is respected" do
        expect(PORO::DB).to receive(:all).with({
          type: :positions,
          modified: true,
          sort: [{id: :desc}],
          parents: []
        }).and_return([])
        instance.load(parents, query, nil)
      end
    end
  end
end
