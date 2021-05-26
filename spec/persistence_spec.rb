require "spec_helper"

RSpec.describe "persistence" do
  let(:payload) do
    {
      data: {
        type: "employees",
        attributes: {first_name: "Jane"}
      }
    }
  end
  let(:klass) do
    Class.new(PORO::EmployeeResource) do
      self.model = PORO::Employee

      def self.name
        "PORO::EmployeeResource"
      end
    end
  end

  around do |e|
    Graphiti.with_context({}, :create) do
      e.run
    end
  end

  def expect_errors(object, expected)
    errors = object.errors.full_messages
    expect(errors).to eq(expected)
  end

  it "can persist single entities" do
    employee = klass.build(payload)
    expect(employee.save).to eq(true)
    expect(employee.data.id).to_not be_nil
    expect(employee.data.first_name).to eq("Jane")
  end

  it "can access the unsaved model after build" do
    employee = klass.build(payload)
    expect(employee.data).to_not be_nil
    expect(employee.data.first_name).to eq("Jane")
    expect(employee.data.id).to be_nil
  end

  xit "can modify attributes directly on the unsaved model before save" do
    employee = klass.build(payload)
    expect(employee.data).to_not be_nil
    employee.data.first_name = "June"

    expect(employee.save).to eq(true)
    expect(employee.data.first_name).to eq("June")
  end

  describe "updating" do
    let!(:employee) { PORO::Employee.create(first_name: "asdf") }

    before do
      payload[:data][:id] = employee.id.to_s
    end

    describe "with scope override" do
      it "is honored" do
        employee = klass.find(payload, {type: "foo"})
        expect {
          employee.update_attributes
        }.to raise_error(Graphiti::Errors::RecordNotFound)
      end
    end

    it "can apply attributes and access model" do
      employee = klass.find(payload)
      expect(employee.data.first_name).to eq("asdf")
      employee.assign_attributes
      expect(employee.data.first_name).to eq("Jane")

      employee = klass.find(payload)
      expect(employee.data.first_name).to eq("asdf")
    end
  end

  describe "destroying" do
    let!(:employee) { PORO::Employee.create(first_name: "asdf") }

    before do
      payload[:data][:id] = employee.id.to_s
    end

    describe "with scope override" do
      it "is honored" do
        employee = klass.find(payload, {type: "foo"})
        expect {
          employee.destroy
        }.to raise_error(Graphiti::Errors::RecordNotFound)
      end
    end
  end

  describe "overrides" do
    before do
      klass.class_eval do
        class << self
          attr_accessor :overridden
        end
      end
    end

    describe "#build" do
      before do
        klass.class_eval do
          def build(model_class)
            self.class.overridden = true
            super
          end
        end
      end

      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Jane"}
          }
        }
      end

      it "overrides correctly" do
        e = klass.build(payload)
        e.save
        expect(klass.overridden).to be(true)
        expect(PORO::Employee.find(e.data.id).first_name).to eq("Jane")
      end
    end

    describe "#assign_attributes" do
      before do
        klass.class_eval do
          def assign_attributes(model, attrs)
            self.class.overridden = true
            super
          end
        end
      end

      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Jane"}
          }
        }
      end

      it "overrides correctly" do
        e = klass.build(payload)
        e.save
        expect(klass.overridden).to be(true)
        expect(PORO::Employee.find(e.data.id).first_name).to eq("Jane")
      end
    end

    describe "#delete" do
      before do
        klass.class_eval do
          def delete(model_instance)
            self.class.overridden = true
            super
          end
        end
      end

      it "overrides correctly" do
        employee = PORO::Employee.create(first_name: "Jane")
        klass.find(id: employee.id).destroy
        expect(klass.overridden).to be(true)
        expect(PORO::Employee.find(employee.id)).to be_nil
      end
    end
  end

  describe "lifecycle hooks" do
    before do
      klass.class_eval do
        class << self
          attr_accessor :calls
        end
        self.calls = []
      end
    end

    RSpec.shared_context "create hooks" do
      subject(:employee) do
        proxy = klass.build(payload)
        proxy.save
        proxy.data
      end
    end

    RSpec.shared_context "update hooks" do
      subject(:employee) do
        proxy = klass.find(payload)
        proxy.update_attributes
        proxy.data
      end

      before do
        employee = PORO::Employee.create
        payload[:data][:id] = employee.id
      end
    end

    RSpec.shared_context "destroy hooks" do
      include_context "update hooks"

      subject(:employee) do
        proxy = klass.find(payload)
        proxy.destroy
        proxy.data
      end
    end

    describe ".before_attributes" do
      RSpec.shared_examples "before attributes" do |opts|
        opts ||= {}

        before do
          klass.class_eval do
            def do_before_attributes(attributes)
              self.class.calls << {
                name: :do_before_attributes,
                args: [attributes.dup]
              }
              attributes[:last_name] = attributes.delete(:first_name)
            end
          end
        end

        if opts[:only_update]
          context "when creating" do
            include_context "create hooks"

            it "does not fire" do
              employee
              expect(klass.calls.length).to eq(0)
            end
          end
        else
          context "when creating" do
            include_context "create hooks"

            it "yields attributes" do
              employee
              expect(klass.calls[0][:args]).to eq([{first_name: "Jane"}])
            end

            it "can modify attributes" do
              expect(employee.last_name).to eq("Jane")
            end
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "yields attributes" do
            employee
            expect(klass.calls[0][:args]).to eq([{first_name: "Jane"}])
          end

          it "can modify attributes" do
            expect(employee.last_name).to eq("Jane")
          end
        end

        context "when destroying" do
          include_context "destroy hooks"

          it "does not fire" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end
      end

      context "when registering via proc" do
        before do
          klass.before_attributes do |attrs|
            do_before_attributes(attrs)
          end
        end

        include_examples "before attributes"
      end

      context "when registering via method" do
        before do
          klass.before_attributes :do_before_attributes
        end

        include_examples "before attributes"
      end

      context "when limiting to update" do
        before do
          klass.before_attributes :do_before_attributes, only: [:update]
        end

        include_examples "before attributes", only_update: true
      end
    end

    describe ".after_attributes" do
      RSpec.shared_examples "after attributes" do |opts|
        opts ||= {}

        before do
          klass.class_eval do
            def do_after_attributes(model)
              self.class.calls << {
                name: :do_after_attributes,
                args: [model.dup]
              }
              model.last_name = model.first_name
            end
          end
        end

        if opts[:only_update]
          context "when creating" do
            include_context "create hooks"

            it "does not fire" do
              employee
              expect(klass.calls.length).to eq(0)
            end
          end
        else
          context "when creating" do
            include_context "create hooks"

            it "is passed model" do
              employee
              expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
            end

            it "can modify the model" do
              expect(employee.last_name).to eq("Jane")
            end
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "is passed model" do
            employee
            expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
          end

          it "can modify the model" do
            expect(employee.last_name).to eq("Jane")
          end
        end

        context "when destroying" do
          include_context "destroy hooks"

          it "does not fire" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end
      end

      context "when registering via proc" do
        before do
          klass.after_attributes do |model|
            do_after_attributes(model)
          end
        end

        include_examples "after attributes"
      end

      context "when registering via method" do
        before do
          klass.after_attributes :do_after_attributes
        end

        include_examples "after attributes"
      end

      context "when limiting to update" do
        before do
          klass.after_attributes :do_after_attributes, only: [:update]
        end

        include_examples "after attributes", only_update: true
      end
    end

    describe ".around_attributes" do
      RSpec.shared_examples "around attributes" do |opts|
        opts ||= {}

        before do
          klass.class_eval do
            def do_around_attributes(attributes)
              self.class.calls << {
                name: :do_around_attributes,
                args: [attributes.dup]
              }
              attributes[:last_name] = attributes.delete(:first_name)
              model_instance = yield attributes
              model_instance.first_name = "after yield"
            end
          end
        end

        if opts[:only_update]
          context "when creating" do
            include_context "create hooks"

            it "does not fire" do
              employee
              expect(klass.calls.length).to eq(0)
            end
          end
        else
          context "when creating" do
            include_context "create hooks"

            it "is passed attributes" do
              employee
              expect(klass.calls[0][:args]).to eq([{first_name: "Jane"}])
            end

            it "can modify the attribute hash" do
              expect(employee.first_name).to eq("after yield")
            end

            it "can modify the resulting model" do
              expect(employee.last_name).to eq("Jane")
            end
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "is passed attributes" do
            employee
            expect(klass.calls[0][:args]).to eq([{first_name: "Jane"}])
          end

          it "can modify the attribute hash" do
            expect(employee.first_name).to eq("after yield")
          end

          it "can modify the resulting model" do
            expect(employee.last_name).to eq("Jane")
          end
        end
      end

      context "when registering via method" do
        before do
          klass.around_attributes :do_around_attributes
        end

        include_examples "around attributes"
      end

      context "when registering via proc" do
        it "raises error" do
          expect {
            klass.around_attributes do
              "dontgethere"
            end
          }.to raise_error(Graphiti::Errors::AroundCallbackProc, /around_attributes/)
        end
      end

      context "when limiting actions" do
        before do
          klass.around_attributes :do_around_attributes, only: [:update]
        end

        include_examples "around attributes", only_update: true
      end
    end

    describe ".before_save" do
      RSpec.shared_examples "before save" do |opts|
        opts ||= {}

        before do
          klass.class_eval do
            def do_before_save(model)
              self.class.calls << {
                name: :do_before_save,
                args: [model.dup]
              }
              model.first_name = "b4 save"
            end
          end
        end

        if opts[:only_update]
          context "when creating" do
            include_context "create hooks"

            it "does not fire" do
              employee
              expect(klass.calls.length).to eq(0)
            end
          end
        else
          context "when creating" do
            include_context "create hooks"

            it "yields model instance" do
              employee
              expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
            end

            it "can modify the model instance" do
              expect(employee.first_name).to eq("b4 save")
            end
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "yields model instance" do
            employee
            expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
          end

          it "can modify the model instance" do
            expect(employee.first_name).to eq("b4 save")
          end
        end

        context "when destroying" do
          include_context "destroy hooks"

          it "does not fire" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end
      end

      context "when registering via proc" do
        before do
          klass.before_save do |model|
            do_before_save(model)
          end
        end

        include_examples "before save"
      end

      context "when registering via method" do
        before do
          klass.before_save :do_before_save
        end

        include_examples "before save"
      end

      context "when limiting actions" do
        before do
          klass.before_save :do_before_save, only: [:update]
        end

        include_examples "before save", only_update: true
      end
    end

    describe ".after_save" do
      RSpec.shared_examples "after save" do |opts|
        opts ||= {}

        before do
          klass.class_eval do
            def do_after_save(model)
              self.class.calls << {
                name: :do_after_save,
                args: [model.dup]
              }
              model.first_name = "after save"
            end
          end
        end

        if opts[:only_update]
          context "when creating" do
            include_context "create hooks"

            it "does not fire" do
              employee
              expect(klass.calls.length).to eq(0)
            end
          end
        else
          context "when creating" do
            include_context "create hooks"

            it "is passed the model instance" do
              employee
              expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
            end

            it "can modify the model instance, but would not persist" do
              expect(employee.first_name).to eq("after save")
              reloaded = PORO::Employee.find(employee.id)
              expect(reloaded.first_name).to eq("Jane")
            end
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "is passed the model instance" do
            employee
            expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
          end

          it "can modify the model instance, but would not persist" do
            expect(employee.first_name).to eq("after save")
            reloaded = PORO::Employee.find(employee.id)
            expect(reloaded.first_name).to eq("Jane")
          end
        end

        context "when destroying" do
          include_context "destroy hooks"

          it "does not fire" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end
      end

      context "when registering via proc" do
        before do
          klass.class_eval do
            after_save do |model|
              do_after_save(model)
            end
          end
        end

        include_examples "after save"
      end

      context "when registering via method" do
        before do
          klass.class_eval do
            after_save :do_after_save
          end
        end

        include_examples "after save"
      end

      context "when limiting actions" do
        before do
          klass.after_save :do_after_save, only: [:update]
        end

        include_examples "after save", only_update: true
      end
    end

    describe ".around_persistence" do
      RSpec.shared_examples "around persistence" do |opts|
        opts ||= {}

        before do
          klass.class_eval do
            before_attributes do |attrs|
              attrs[:first_name] = "#{attrs[:first_name]}mid"
            end

            def do_around_persistence(attributes)
              attributes[:first_name] = "b4"
              model = yield
              model.update_attributes(first_name: "#{model.first_name}after")
              1 # return value shouldnt matter
            end
          end
        end

        if opts[:only_update]
          context "when creating" do
            include_context "create hooks"

            it "does not fire" do
              employee
              expect(klass.calls.length).to eq(0)
            end
          end
        else
          context "when creating" do
            include_context "create hooks"

            it "can modify attributes and the saved model" do
              reloaded = PORO::Employee.find(employee.id)
              expect(reloaded.first_name).to eq("b4midafter")
            end
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "can modify attributes and the saved model" do
            reloaded = PORO::Employee.find(employee.id)
            expect(reloaded.first_name).to eq("b4midafter")
          end
        end
      end

      context "when registering via method" do
        before do
          klass.around_persistence :do_around_persistence
        end

        include_examples "around persistence"
      end

      context "when registering via proc" do
        it "raises error" do
          expect {
            klass.around_persistence do
              "dontgethere"
            end
          }.to raise_error(Graphiti::Errors::AroundCallbackProc, /around_persistence/)
        end
      end

      context "when limiting actions" do
        before do
          klass.around_persistence :do_around_persistence, only: [:update]
        end

        include_examples "around persistence", only_update: true
      end
    end

    describe ".around_save" do
      RSpec.shared_examples "around save" do |opts|
        opts ||= {}

        before do
          klass.class_eval do
            def do_around_save(model)
              self.class.calls << {
                name: :do_around_save,
                args: [model.dup]
              }
              model.first_name = "b4 yield"
              model_instance = yield model
              model_instance.first_name = "after yield"
            end
          end
        end

        if opts[:only_update]
          context "when creating" do
            include_context "create hooks"

            it "does not fire" do
              employee
              expect(klass.calls.length).to eq(0)
            end
          end
        else
          context "when creating" do
            include_context "create hooks"

            it "yields the model" do
              employee
              expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
            end

            it "can modify the model before yielding" do
              expect(employee.first_name).to eq("after yield")
            end

            it "can modify the model with unpersisted changes after yielding" do
              reloaded = PORO::Employee.find(employee.id)
              expect(reloaded.first_name).to eq("b4 yield")
            end
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "yields the model" do
            employee
            expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
          end

          it "can modify the model before yielding" do
            expect(employee.first_name).to eq("after yield")
          end

          it "can modify the model with unpersisted changes after yielding" do
            reloaded = PORO::Employee.find(employee.id)
            expect(reloaded.first_name).to eq("b4 yield")
          end
        end
      end

      context "when registering via method" do
        before do
          klass.around_save :do_around_save
        end

        include_examples "around save"
      end

      context "when registering via proc" do
        it "raises error" do
          expect {
            klass.around_save :do_around_save do
              "dontgethere"
            end
          }.to raise_error(Graphiti::Errors::AroundCallbackProc, /around_save/)
        end
      end

      context "when limiting actions" do
        before do
          klass.around_save :do_around_save, only: [:update]
        end

        include_examples "around save", only_update: true
      end
    end

    describe ".before_destroy" do
      RSpec.shared_examples "before_destroy" do
        before do
          klass.class_eval do
            def do_before_destroy(model)
              model.first_name = "updated b4 destroy"
              self.class.calls << {
                name: :do_before_destroy,
                args: [model.dup]
              }
            end
          end
        end

        context "when creating" do
          include_context "create hooks"

          it "is not called" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "is not called" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end

        context "when destroying" do
          include_context "destroy hooks"

          it "is called, yielding the model instance" do
            employee
            expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
            expect(klass.calls[0][:args][0].first_name).to eq("updated b4 destroy")
          end
        end
      end

      context "when registering via proc" do
        before do
          klass.before_destroy do |model|
            do_before_destroy(model)
          end
        end

        include_examples "before_destroy"
      end

      context "when registering via method" do
        before do
          klass.before_destroy :do_before_destroy
        end

        include_examples "before_destroy"
      end
    end

    describe ".after_destroy" do
      RSpec.shared_examples "after_destroy" do
        before do
          klass.class_eval do
            def do_after_destroy(model)
              model.first_name = "updated after destroy"
              self.class.calls << {
                name: :do_after_destroy,
                args: [model.dup]
              }
            end
          end
        end

        context "when creating" do
          include_context "create hooks"

          it "is not called" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "is not called" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end

        context "when destroying" do
          include_context "destroy hooks"

          it "is called, yielding the model instance" do
            employee
            expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
            expect(klass.calls[0][:args][0].first_name).to eq("updated after destroy")
          end
        end
      end

      context "when registering via proc" do
        before do
          klass.after_destroy do |model|
            do_after_destroy(model)
          end
        end

        include_examples "after_destroy"
      end

      context "when registering via method" do
        before do
          klass.after_destroy :do_after_destroy
        end

        include_examples "after_destroy"
      end
    end

    describe ".around_destroy" do
      RSpec.shared_examples "around_destroy" do
        before do
          klass.class_eval do
            def do_around_destroy(model)
              model.first_name = "updated b4 destroy"
              self.class.calls << {
                name: :do_around_destroy,
                args: [model.dup]
              }
              if PORO::Employee.find(model.id).nil?
                raise "something went wrong"
              end
              yield model
              unless PORO::Employee.find(model.id).nil?
                raise "something went wrong"
              end
            end
          end
        end

        context "when creating" do
          include_context "create hooks"

          it "is not called" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end

        context "when updating" do
          include_context "update hooks"

          it "is not called" do
            employee
            expect(klass.calls.length).to be_zero
          end
        end

        context "when destroying" do
          include_context "destroy hooks"

          it "is called, yielding the model instance" do
            employee
            expect(klass.calls[0][:args][0]).to be_a(PORO::Employee)
            expect(klass.calls[0][:args][0].first_name).to eq("updated b4 destroy")
            expect(PORO::Employee.find(employee.id)).to eq(nil)
          end
        end
      end

      context "when registering via proc" do
        it "raises error" do
          expect {
            klass.around_destroy do |model|
              "dontgethere"
            end
          }.to raise_error(Graphiti::Errors::AroundCallbackProc, /around_destroy/)
        end
      end

      context "when registering via method" do
        before do
          klass.around_destroy :do_around_destroy
        end

        include_examples "around_destroy"
      end
    end

    describe "stacking callbacks" do
      before do
        klass.before_attributes do |attrs|
          attrs[:first_name] << "_b4attrsA"
        end

        klass.before_attributes do |attrs|
          attrs[:first_name] << "_b4attrsB"
        end

        klass.before_attributes only: [:update] do |attrs|
          attrs[:first_name] << "_b4attrsC"
        end

        klass.after_attributes do |model|
          model.first_name << "_afterattrsA"
        end

        klass.after_attributes do |model|
          model.first_name << "_afterattrsB"
        end

        klass.after_attributes only: [:update] do |model|
          model.first_name << "_afterattrsC"
        end

        klass.around_attributes :around_attrs_a
        klass.around_attributes :around_attrs_b
        klass.around_attributes :around_attrs_c, only: [:update]

        klass.before_save do |model|
          model.first_name << "_b4saveA"
        end

        klass.before_save do |model|
          model.first_name << "_b4saveB"
        end

        klass.before_save only: [:update] do |model|
          model.first_name << "_b4saveC"
        end

        klass.after_save do |model|
          model.first_name << "_aftersaveA"
        end

        klass.after_save do |model|
          model.first_name << "_aftersaveB"
        end

        klass.after_save only: [:update] do |model|
          model.first_name << "_aftersaveC"
        end

        klass.around_save :around_save_a
        klass.around_save :around_save_b
        klass.around_save :around_save_c, only: [:update]

        klass.around_persistence :around_persistence_a
        klass.around_persistence :around_persistence_b
        klass.around_persistence :around_persistence_c, only: [:update]

        klass.class_eval do
          def around_attrs_a(attrs)
            attrs[:first_name] << "_aroundattrsA1"
            yield attrs
            attrs[:first_name] << "_aroundattrsA2"
          end

          def around_attrs_b(attrs)
            attrs[:first_name] << "_aroundattrsB1"
            yield attrs
            attrs[:first_name] << "_aroundattrsB2"
          end

          def around_attrs_c(attrs)
            attrs[:first_name] << "_aroundattrsC1"
            yield attrs
            attrs[:first_name] << "_aroundattrsC2"
          end

          def around_save_a(model)
            model.first_name << "_aroundsaveA1"
            yield model
            model.first_name << "_aroundsaveA2"
          end

          def around_save_b(model)
            model.first_name << "_aroundsaveB1"
            yield model
            model.first_name << "_aroundsaveB2"
          end

          def around_save_c(model)
            model.first_name << "_aroundsaveC1"
            yield model
            model.first_name << "_aroundsaveC2"
          end

          def around_persistence_a(attrs)
            attrs[:first_name] << "_aroundpersA1"
            model = yield attrs
            model.first_name << "_aroundpersA2"
          end

          def around_persistence_b(attrs)
            attrs[:first_name] << "_aroundpersB1"
            model = yield attrs
            model.first_name << "_aroundpersB2"
          end

          def around_persistence_c(attrs)
            attrs[:first_name] << "_aroundpersC1"
            model = yield attrs
            model.first_name << "_aroundpersC2"
          end
        end
      end

      it "can stack multiple callbacks on create" do
        proxy = klass.build(payload)
        proxy.save
        expect(proxy.data.first_name.split("_")).to eq([
          "Jane",
          "aroundpersA1",
          "aroundpersB1",
          "aroundattrsA1",
          "aroundattrsB1",
          "b4attrsA",
          "b4attrsB",
          "afterattrsA",
          "afterattrsB",
          "aroundattrsB2",
          "aroundattrsA2",
          "aroundsaveA1",
          "aroundsaveB1",
          "b4saveA",
          "b4saveB",
          "aftersaveA",
          "aftersaveB",
          "aroundsaveB2",
          "aroundsaveA2",
          "aroundpersB2",
          "aroundpersA2"
        ])
      end

      it "can stack multiple callbacks on update" do
        employee = PORO::Employee.create
        payload[:data][:id] = employee.id
        proxy = klass.find(payload)
        proxy.update_attributes
        expect(proxy.data.first_name.split("_")).to eq([
          "Jane",
          "aroundpersA1",
          "aroundpersB1",
          "aroundpersC1",
          "aroundattrsA1",
          "aroundattrsB1",
          "aroundattrsC1",
          "b4attrsA",
          "b4attrsB",
          "b4attrsC",
          "afterattrsA",
          "afterattrsB",
          "afterattrsC",
          "aroundattrsC2",
          "aroundattrsB2",
          "aroundattrsA2",
          "aroundsaveA1",
          "aroundsaveB1",
          "aroundsaveC1",
          "b4saveA",
          "b4saveB",
          "b4saveC",
          "aftersaveA",
          "aftersaveB",
          "aftersaveC",
          "aroundsaveC2",
          "aroundsaveB2",
          "aroundsaveA2",
          "aroundpersC2",
          "aroundpersB2",
          "aroundpersA2"
        ])
      end
    end
  end

  context "when in need of meta information in a hook" do
    subject(:save) do
      instance = klass.build(payload)
      instance.save
      instance
    end

    let(:payload) do
      {
        data: {
          type: "employees",
          attributes: {first_name: "Jane"},
          relationships: {
            positions: {
              data: [{
                type: "positions", 'temp-id': "abc123", method: "create"
              }]
            }
          }
        },
        included: [
          {
            type: "positions",
            'temp-id': "abc123",
            attributes: {title: "Engineer"}
          }
        ]
      }
    end

    let(:position_resource) do
      Class.new(PORO::PositionResource) do
        class << self
          attr_accessor :meta
        end

        def self.name
          "PORO::PositionResource"
        end

        attribute :employee_id, :integer
      end
    end

    before do
      klass.class_eval do
        class << self
          attr_accessor :meta
        end
      end
      klass.has_many :positions, resource: position_resource
    end

    def assert_meta
      expect(klass.meta[:method]).to eq(:create)
      expect(klass.meta[:attributes]).to eq(first_name: "Jane")
      expect(klass.meta[:relationships]).to eq({
        positions: [{
          attributes: {employee_id: 1, title: "Engineer"},
          meta: {
            jsonapi_type: "positions",
            method: :create,
            temp_id: "abc123",
            payload_path: ["included", 0]
          },
          relationships: {}
        }]
      })

      meta = position_resource.meta
      expect(meta[:method]).to eq(:create)
      expect(meta[:temp_id]).to eq("abc123")
      expect(meta[:caller_model]).to be_a(PORO::Employee)
      expect(meta[:attributes]).to eq(employee_id: 1, title: "Engineer")
      expect(meta[:relationships]).to eq({})
    end

    context "when before_attributes" do
      context "via proc" do
        before do
          klass.class_eval do
            before_attributes do |attrs, meta|
              self.class.meta = meta
            end
          end

          position_resource.class_eval do
            before_attributes do |attrs, meta|
              self.class.meta = meta
            end
          end
        end

        it "works" do
          save
          assert_meta
        end
      end

      context "via method" do
        before do
          klass.class_eval do
            before_attributes :do_meta

            def do_meta(attributes, meta)
              self.class.meta = meta
            end
          end

          position_resource.class_eval do
            before_attributes :do_meta

            def do_meta(attributes, meta)
              self.class.meta = meta
            end
          end
        end

        it "works" do
          save
          assert_meta
        end
      end
    end

    context "when after_attributes" do
      context "via proc" do
        before do
          klass.class_eval do
            after_attributes do |model, meta|
              self.class.meta = meta
            end
          end

          position_resource.class_eval do
            after_attributes do |attrs, meta|
              self.class.meta = meta
            end
          end
        end

        it "works" do
          save
          assert_meta
        end
      end

      context "via method name" do
        before do
          klass.class_eval do
            after_attributes :do_after_attributes

            def do_after_attributes(attrs, meta)
              self.class.meta = meta
            end
          end

          position_resource.class_eval do
            after_attributes :do_after_attributes

            def do_after_attributes(attrs, meta)
              self.class.meta = meta
            end
          end
        end

        it "works" do
          save
          assert_meta
        end
      end
    end

    context "when around_attributes" do
      before do
        klass.class_eval do
          around_attributes :do_around_attributes

          def do_around_attributes(attrs, meta)
            self.class.meta = meta
            yield attrs
          end
        end

        position_resource.class_eval do
          around_attributes :do_around_attributes

          def do_around_attributes(attrs, meta)
            self.class.meta = meta
            yield attrs
          end
        end
      end

      it "works" do
        save
        assert_meta
      end
    end

    context "when before_save" do
      context "when registered via proc" do
        before do
          klass.class_eval do
            before_save do |model, meta|
              self.class.meta = meta
            end
          end

          position_resource.class_eval do
            before_save do |model, meta|
              self.class.meta = meta
            end
          end
        end

        it "works" do
          save
          assert_meta
        end
      end

      context "when registered via method" do
        before do
          klass.class_eval do
            before_save :do_before_save

            def do_before_save(model, meta)
              self.class.meta = meta
            end
          end

          position_resource.class_eval do
            before_save :do_before_save

            def do_before_save(model, meta)
              self.class.meta = meta
            end
          end
        end

        it "works" do
          save
          assert_meta
        end
      end
    end

    context "after_save" do
      context "when registered via proc" do
        before do
          klass.class_eval do
            after_save do |model, meta|
              self.class.meta = meta
            end
          end

          position_resource.class_eval do
            after_save do |model, meta|
              self.class.meta = meta
            end
          end
        end

        it "works" do
          save
          assert_meta
        end
      end

      context "when registered via method" do
        before do
          klass.class_eval do
            after_save :do_after_save

            def do_after_save(model, meta)
              self.class.meta = meta
            end
          end

          position_resource.class_eval do
            after_save :do_after_save

            def do_after_save(model, meta)
              self.class.meta = meta
            end
          end
        end

        it "works" do
          save
          assert_meta
        end
      end
    end

    context "around_save" do
      before do
        klass.class_eval do
          around_save :do_around_save

          def do_around_save(model, meta)
            self.class.meta = meta
            yield model
          end
        end

        position_resource.class_eval do
          around_save :do_around_save

          def do_around_save(model, meta)
            self.class.meta = meta
            yield model
          end
        end
      end

      it "works" do
        save
        assert_meta
      end
    end

    context "around_persistence" do
      before do
        klass.class_eval do
          around_persistence :do_around_persistence

          def do_around_persistence(attrs, meta)
            self.class.meta = meta
            yield attrs
          end
        end

        position_resource.class_eval do
          around_persistence :do_around_persistence

          def do_around_persistence(attrs, meta)
            self.class.meta = meta
            yield attrs
          end
        end
      end

      it "works" do
        save
        assert_meta
      end
    end

    context "before_destroy" do
      context "when registered via proc" do
        before do
          klass.class_eval do
            before_destroy do |model, meta|
              self.class.meta = meta
            end
          end
        end

        it "works" do
          employee = PORO::Employee.create(first_name: "Jane")
          klass.find(id: employee.id).destroy
          expect(klass.meta).to eq(method: :destroy)
        end
      end

      context "when registered via method" do
        before do
          klass.class_eval do
            before_destroy :do_before_destroy

            def do_before_destroy(model, meta)
              self.class.meta = meta
            end
          end
        end

        it "works" do
          employee = PORO::Employee.create(first_name: "Jane")
          klass.find(id: employee.id).destroy
          expect(klass.meta).to eq(method: :destroy)
        end
      end

      context "when sideposted" do
        let(:employee) { PORO::Employee.create(first_name: "Jane") }
        let(:position) { PORO::Position.create(title: "foo") }

        let(:payload) do
          {
            data: {
              type: "employees",
              id: employee.id,
              relationships: {
                positions: {
                  data: [{
                    id: position.id.to_s,
                    type: "positions",
                    method: :destroy
                  }]
                }
              }
            }
          }
        end

        let(:position_resource) do
          Class.new(PORO::PositionResource) do
            class << self
              attr_accessor :meta
            end
            def self.name
              "PORO::PositionResource"
            end
            attribute :employee_id, :integer
            before_destroy do |model, meta|
              self.class.meta = meta
            end
          end
        end

        before do
          klass.has_many :positions, resource: position_resource
        end

        it "works" do
          klass.find(payload).save
          expect(position_resource.meta.except(:caller_model)).to eq({
            method: :destroy,
            attributes: {employee_id: nil, id: 1},
            relationships: {},
            temp_id: nil
          })
          expect(position_resource.meta[:caller_model]).to be_a(PORO::Employee)
        end
      end
    end

    context "after_destroy" do
      context "when registered via proc" do
        before do
          klass.class_eval do
            after_destroy do |model, meta|
              self.class.meta = meta
            end
          end
        end

        it "works" do
          employee = PORO::Employee.create(first_name: "Jane")
          klass.find(id: employee.id).destroy
          expect(klass.meta).to eq(method: :destroy)
        end
      end

      context "when registered via method" do
        before do
          klass.class_eval do
            after_destroy :do_after_destroy

            def do_after_destroy(model, meta)
              self.class.meta = meta
            end
          end
        end

        it "works" do
          employee = PORO::Employee.create(first_name: "Jane")
          klass.find(id: employee.id).destroy
          expect(klass.meta).to eq(method: :destroy)
        end
      end
    end

    context "around_destroy" do
      before do
        klass.class_eval do
          around_destroy :do_around_destroy

          def do_around_destroy(model, meta)
            self.class.meta = meta
            yield model
          end
        end
      end

      it "works" do
        employee = PORO::Employee.create(first_name: "Jane")
        klass.find(id: employee.id).destroy
        expect(klass.meta).to eq(method: :destroy)
      end
    end

    context "#build" do
      before do
        klass.class_eval do
          def build(model_class, meta)
            self.class.meta = meta
            super
          end
        end

        position_resource.class_eval do
          def build(model_class, meta)
            self.class.meta = meta
            super
          end
        end
      end

      it "works" do
        save
        assert_meta
      end
    end

    context "#save" do
      before do
        klass.class_eval do
          def save(model, meta)
            self.class.meta = meta
            super
          end
        end

        position_resource.class_eval do
          def save(model, meta)
            self.class.meta = meta
            super
          end
        end
      end

      it "works" do
        save
        assert_meta
      end
    end

    context "#assign_attributes" do
      before do
        klass.class_eval do
          def assign_attributes(model, attrs, meta)
            self.class.meta = meta
            super
          end
        end

        position_resource.class_eval do
          def assign_attributes(model, attrs, meta)
            self.class.meta = meta
            super
          end
        end
      end

      it "works" do
        save
        assert_meta
      end
    end

    context "#delete" do
      before do
        klass.class_eval do
          def delete(model, meta)
            self.class.meta = meta
            super
          end
        end
      end

      it "works" do
        employee = PORO::Employee.create(first_name: "Jane")
        klass.find(id: employee.id).destroy
        expect(klass.meta).to eq(method: :destroy)
      end
    end
  end

  context "when given an attribute that does not exist" do
    before do
      payload[:data][:attributes] = {foo: "bar"}
    end

    it "raises appropriate error" do
      expect {
        klass.build(payload).save
      }.to(raise_error { |e|
        expect(e).to be_a Graphiti::Errors::InvalidRequest
        expect(e.errors.full_messages).to eq ["data.attributes.foo is an unknown attribute"]
      })
    end
  end

  context "when given an attribute that is not writable" do
    before do
      klass.attribute :foo, :string, writable: false
      payload[:data][:attributes] = {foo: "bar"}
    end

    it "raises appropriate error" do
      expect {
        klass.build(payload).save
      }.to(raise_error { |e|
        expect(e).to be_a Graphiti::Errors::InvalidRequest
        expect(e.errors.full_messages).to eq ["data.attributes.foo cannot be written"]
      })
    end
  end

  context "when given an unwritable id" do
    before do
      klass.attribute :id, :string, writable: false
      payload[:data][:id] = "123"
    end

    context "and it is a create operation" do
      it "works" do
        expect {
          instance = klass.build(payload)
          instance.save
        }.to raise_error(Graphiti::Errors::InvalidRequest, /data.attributes.id/)
      end
    end

    context "and it is an update operation" do
      let!(:record) do
        PORO::Employee.create(id: 123, first_name: "asdf")
      end

      it "works" do
        instance = klass.find(payload)
        expect {
          expect(instance.update_attributes).to eq(true)
        }.to change { klass.find(payload).data.first_name }
          .from("asdf").to("Jane")
      end
    end
  end

  context "when given a writable attribute of the wrong type" do
    before do
      klass.attribute :foo, :integer
      payload[:data][:attributes] = {foo: "bar"}
    end

    it "raises helpful error" do
      expect {
        klass.build(payload).save
      }.to(raise_error { |e|
        expect(e).to be_a Graphiti::Errors::InvalidRequest
        expect(e.errors.full_messages).to eq ["data.attributes.foo should be type integer"]
      })
    end

    context "and it can coerce" do
      before do
        payload[:data][:attributes] = {first_name: 1}
      end

      it "works" do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        expect(employee.data.first_name).to eq("1")
      end
    end
  end

  describe "types" do
    def save(value)
      payload[:data][:attributes][:age] = value
      employee = klass.build(payload)
      employee.save
      employee.data.age
    end

    context "when string" do
      let!(:value) { 1 }

      before do
        klass.attribute :age, :string
      end

      it "coerces" do
        expect(save(1)).to eq("1")
      end
    end

    context "when integer" do
      before do
        klass.attribute :age, :integer
      end

      it "coerces strings" do
        expect(save("1")).to eq(1)
      end

      it "allows nils" do
        expect(save(nil)).to eq(nil)
      end

      it "does not coerce blank string to 0" do
        expect {
          save("")
        }.to(raise_error { |e|
          expect(e).to be_a Graphiti::Errors::InvalidRequest
          expect(e.errors.full_messages).to eq ["data.attributes.age should be type integer"]
        })
      end

      context "when cannot coerce" do
        it "raises error" do
          expect {
            save({})
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.attributes.age should be type integer"]
          })
        end
      end
    end

    context "when decimal" do
      before do
        klass.attribute :age, :big_decimal
      end

      it "coerces integers" do
        expect(save(1)).to eq(BigDecimal("1"))
      end

      it "coerces strings" do
        expect(save("1")).to eq(BigDecimal("1"))
      end

      it "allows nils" do
        expect(save(nil)).to eq(nil)
      end

      context "when cannot coerce" do
        it "raises error" do
          expect {
            save({})
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.attributes.age should be type big_decimal"]
          })
        end
      end
    end

    context "when float" do
      before do
        klass.attribute :age, :float
      end

      it "coerces strings" do
        expect(save("1.1")).to eq(1.1)
      end

      it "coerces integers" do
        expect(save(1)).to eq(1.0)
      end

      it "allows nils" do
        expect(save(nil)).to eq(nil)
      end

      context "when cannot coerce" do
        it "raises error" do
          expect {
            save({})
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.attributes.age should be type float"]
          })
        end
      end
    end

    context "when boolean" do
      before do
        klass.attribute :age, :boolean
      end

      it "coerces strings" do
        expect(save("true")).to eq(true)
      end

      it "coerces integers" do
        expect(save(1)).to eq(true)
      end

      it "allows nils" do
        expect(save(nil)).to eq(nil)
      end

      context "when cannot coerce" do
        it "raises error" do
          expect {
            save({})
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.attributes.age should be type boolean"]
          })
        end
      end
    end

    context "when date" do
      before do
        klass.attribute :age, :date
      end

      it "coerces Date strings to correct format" do
        expect(save("2018/01/06")).to eq(Date.parse("2018-01-06"))
      end

      it "coerces Time strings to correct format" do
        time = Time.parse("2018/01/06 4:36pm EST")
        expect(save(time.iso8601)).to eq(Date.parse("2018-01-06"))
      end

      it "coerces Time to correct date format" do
        time = Time.parse("2018/01/06 4:36pm EST")
        expect(save(time)).to eq(Date.parse("2018-01-06"))
      end

      it "allows nils" do
        expect(save(nil)).to eq(nil)
      end

      context "when only month" do
        it "defaults to first of the month" do
          expect(save("2018/01")).to eq(Date.parse("2018-01-01"))
        end
      end

      context "when cannot coerce" do
        it "raises error" do
          expect {
            save({})
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.attributes.age should be type date"]
          })
        end
      end
    end

    context "when datetime" do
      before do
        klass.attribute :age, :datetime
      end

      it "coerces Time correctly" do
        time = Time.parse("2018-01-06 4:36pm PST")
        expect(save(time)).to eq(DateTime.parse("2018-01-06 4:36pm PST"))
      end

      it "coerces Date correctly" do
        date = Date.parse("2018-01-06")
        expect(save(date)).to eq(DateTime.parse("2018-01-06"))
      end

      it "coerces date strings correctly" do
        expect(save("2018-01-06")).to eq(DateTime.parse("2018-01-06"))
      end

      it "preserves date string zones" do
        result = save("2018-01-06 4:36pm PST")
        expect(result.zone).to eq("-08:00")
      end

      it "coerces time strings correctly" do
        str = "2018-01-06 4:36pm PST"
        time = Time.parse(str)
        expect(save(time.iso8601)).to eq(DateTime.parse(str))
      end

      it "preserves time string zones" do
        time = Time.parse("2018-01-06 4:36pm PST")
        result = save(time.iso8601)
        expect(result.zone).to eq("-08:00")
      end

      it "allows nils" do
        expect(save(nil)).to eq(nil)
      end

      context "when cannot coerce" do
        it "raises error" do
          expect {
            save({})
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.attributes.age should be type datetime"]
          })
        end
      end
    end

    context "when hash" do
      before do
        klass.attribute :age, :hash
      end

      it "works" do
        expect(save({foo: "bar"})).to eq(foo: "bar")
      end

      # I'm OK with eventually coercing to symbols, but this seems fine
      it "allows string keys" do
        expect(save({"foo" => "bar"})).to eq("foo" => "bar")
      end

      context "when cannot coerce" do
        it "raises error" do
          expect {
            save([:foo, :bar])
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.attributes.age should be type hash"]
          })
        end
      end
    end

    context "when array" do
      before do
        klass.attribute :age, :array
      end

      it "works" do
        expect(save([:foo, :bar])).to eq([:foo, :bar])
      end

      it "raises error on single values" do
        expect {
          save(:foo)
        }.to(raise_error { |e|
          expect(e).to be_a Graphiti::Errors::InvalidRequest
          expect(e.errors.full_messages).to eq ["data.attributes.age should be type array"]
        })
      end

      it "does NOT allow nils" do
        expect {
          save(nil)
        }.to(raise_error { |e|
          expect(e).to be_a Graphiti::Errors::InvalidRequest
          expect(e.errors.full_messages).to eq ["data.attributes.age should be type array"]
        })
      end

      context "when cannot coerce" do
        it "raises error" do
          expect {
            save({})
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.attributes.age should be type array"]
          })
        end
      end
    end

    # test for all array_of_*
    context "when array_of_integers" do
      before do
        klass.attribute :age, :array_of_integers
      end

      it "works" do
        expect(save([1, 2])).to eq([1, 2])
      end

      it "applies basic coercion" do
        expect(save(["1", "2"])).to eq([1, 2])
      end

      it "raises error on single values" do
        expect {
          save(1)
        }.to(raise_error { |e|
          expect(e).to be_a Graphiti::Errors::InvalidRequest
          expect(e.errors.full_messages).to eq ["data.attributes.age should be type array_of_integers"]
        })
      end

      it "raises error on nils" do
        expect {
          save(nil)
        }.to(raise_error { |e|
          expect(e).to be_a Graphiti::Errors::InvalidRequest
          expect(e.errors.full_messages).to eq ["data.attributes.age should be type array_of_integers"]
        })
      end

      context "when cannot coerce" do
        it "raises error" do
          expect {
            save({})
          }.to(raise_error { |e|
            expect(e).to be_a Graphiti::Errors::InvalidRequest
            expect(e.errors.full_messages).to eq ["data.attributes.age should be type array_of_integers"]
          })
        end
      end
    end

    context "when custom type" do
      before do
        type = Dry::Types::Nominal
          .new(nil)
          .constructor { |input|
            "custom!"
          }
        Graphiti::Types[:custom] = {
          write: type,
          read: type,
          params: type,
          description: "test",
          kind: "scalar"
        }
        klass.attribute :age, :custom
      end

      after do
        Graphiti::Types.map.delete(:custom)
      end

      it "works" do
        expect(save("foo")).to eq("custom!")
      end
    end
  end

  describe "nested writes" do
    describe "has_many" do
      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Jane"},
            relationships: {
              positions: {
                data: [{
                  type: "positions",
                  'temp-id': "abc123",
                  method: "create"
                }]
              }
            }
          },
          included: [
            {
              type: "positions",
              'temp-id': "abc123",
              attributes: {title: "mytitle"}
            }
          ]
        }
      end

      let(:position_model) do
        Class.new(PORO::Position) do
          validates :title, presence: true

          def self.name
            "PORO::Position"
          end
        end
      end

      let(:position_resource) do
        model = position_model
        Class.new(PORO::PositionResource) do
          self.model = model
          attribute :employee_id, :integer, only: [:writable]
          attribute :title, :string

          def self.name
            "PORO::PositionResource"
          end
        end
      end

      before do
        klass.has_many :positions, resource: position_resource
      end

      it "works" do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.first_name).to eq("Jane")
        expect(data.positions.length).to eq(1)
        positions = data.positions
        expect(positions[0].id).to be_present
        expect(positions[0].title).to eq("mytitle")
      end

      context "when a nested validation error" do
        before do
          payload[:included][0].delete(:attributes)
        end

        it "responds correctly" do
          employee = klass.build(payload)
          expect(employee.save).to eq(false)
          expect_errors(employee.data.positions[0], ["Title can't be blank"])
        end
      end
    end

    describe "belongs_to" do
      let(:payload) do
        {
          data: {
            type: "employees",
            relationships: {
              classification: {
                data: {
                  type: "classifications",
                  'temp-id': "abc123",
                  method: "create"
                }
              }
            }
          },
          included: [
            {
              'temp-id': "abc123",
              type: "classifications",
              attributes: {description: "classy"}
            }
          ]
        }
      end

      let(:classification_model) do
        Class.new(PORO::Classification) do
          validates :description, presence: true

          def self.name
            "PORO::Classification"
          end
        end
      end

      let(:classification_resource) do
        model = classification_model
        Class.new(PORO::ClassificationResource) do
          self.model = model
          attribute :description, :string

          def self.name
            "PORO::ClassificationResource"
          end
        end
      end

      before do
        klass.attribute :classification_id, :integer, only: [:writable]
        klass.belongs_to :classification, resource: classification_resource
      end

      it "works" do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.classification).to be_a(classification_model)
        expect(data.classification.id).to be_present
        expect(data.classification.description).to eq("classy")
      end

      context "when a nested validation error" do
        before do
          payload[:included][0].delete(:attributes)
        end

        it "responds correctly" do
          employee = klass.build(payload)
          expect(employee.save).to eq(false)
          expect_errors(employee.data.classification, ["Description can't be blank"])
        end
      end

      context "linking to an non-existing related record" do
        let(:payload) do
          {
            data: {
              type: "employees",
              relationships: {
                classification: {
                  data: {
                    type: "classifications",
                    id: "123"
                  }
                }
              }
            }
          }
        end

        context "when raise_on_missing_sidepost is true" do
          it "responds correctly" do
            employee = klass.build(payload)
            expect { employee.save }.to raise_error(
              Graphiti::Errors::RecordNotFound,
              "The referenced resource 'classification' with id '123' could not be found. " \
              "Referenced at 'relationships/classifications'"
            )
          end
        end

        context "when raise_on_missing_sidepost is false" do
          before do
            Graphiti.config.raise_on_missing_sidepost = false
          end

          after do
            Graphiti.config.raise_on_missing_sidepost = true
          end

          it "responds correctly" do
            employee = klass.build(payload)
            employee.save
            errors = employee.data.classification.errors
            expect(errors.details).to eq(base: [{error: :not_found}])
            expect(errors.messages).to eq(base: ["could not be found"])
            model = errors.instance_variable_get(:@target)
            expect(model.id).to eq("123")
            expect(model.pointer).to eq("data/relationships/classifications")
          end
        end
      end
    end

    describe "has_one" do
      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Jane"},
            relationships: {
              bio: {
                data: {
                  type: "bios",
                  'temp-id': "abc123",
                  method: "create"
                }
              }
            }
          },
          included: [
            {
              type: "bios",
              'temp-id': "abc123",
              attributes: {text: "mytext"}
            }
          ]
        }
      end

      let(:bio_model) do
        Class.new(PORO::Bio) do
          validates :text, presence: true

          def self.name
            "PORO::Bio"
          end
        end
      end

      let(:bio_resource) do
        model = bio_model
        Class.new(PORO::BioResource) do
          self.model = model
          attribute :employee_id, :integer, only: [:writable]
          attribute :text, :string

          def self.name
            "PORO::BioResource"
          end
        end
      end

      before do
        klass.has_one :bio, resource: bio_resource
      end

      it "works" do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.first_name).to eq("Jane")
        expect(data.bio.id).to be_present
        expect(data.bio.text).to eq("mytext")
      end

      context "when a nested validation error" do
        before do
          payload[:included][0].delete(:attributes)
        end

        it "responds correctly" do
          employee = klass.build(payload)
          expect(employee.save).to eq(false)
          expect_errors(employee.data.bio, ["Text can't be blank"])
        end
      end
    end

    describe "many_to_many" do
      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Jane"},
            relationships: {
              teams: {
                data: [{
                  type: "teams",
                  'temp-id': "abc123",
                  method: "create"
                }]
              }
            }
          },
          included: [
            {
              type: "teams",
              'temp-id': "abc123",
              attributes: {name: "ip"}
            }
          ]
        }
      end

      let(:team_model) do
        Class.new(PORO::Team) do
          validates :name, presence: true

          def self.name
            "PORO::Team"
          end
        end
      end

      let(:team_resource) do
        model = team_model
        Class.new(PORO::TeamResource) do
          self.model = model
          attribute :name, :string

          def self.name
            "PORO::TeamResource"
          end
        end
      end

      before do
        klass.many_to_many :teams,
          resource: team_resource,
          foreign_key: {team_memberships: :team_id}
      end

      it "works" do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.first_name).to eq("Jane")
        expect(data.teams.length).to eq(1)
        expect(data.teams[0].name).to eq("ip")
      end

      context "when a nested validation error" do
        before do
          payload[:included][0].delete(:attributes)
        end

        it "responds correctly" do
          employee = klass.build(payload)
          expect(employee.save).to eq(false)
          expect_errors(employee.data.teams[0], ["Name can't be blank"])
        end
      end
    end

    describe "polymorphic_belongs_to" do
      let(:jsonapi_type) { "visas" }
      let(:payload) do
        {
          data: {
            type: "employees",
            relationships: {
              credit_card: {
                data: {
                  type: jsonapi_type,
                  'temp-id': "abc123",
                  method: "create"
                }
              }
            }
          },
          included: [
            {
              'temp-id': "abc123",
              type: jsonapi_type,
              attributes: {number: 123456}
            }
          ]
        }
      end

      let(:visa_model) do
        Class.new(PORO::Visa) do
          validates :number, presence: true

          def self.name
            "PORO::Visa"
          end
        end
      end

      let(:visa_resource) do
        model = visa_model
        Class.new(PORO::VisaResource) do
          self.type = :visas
          self.model = model
          attribute :number, :integer

          def self.name
            "PORO::VisaResource"
          end
        end
      end

      before do
        resource = visa_resource
        klass.polymorphic_belongs_to :credit_card do
          group_by(:credit_card_type) do
            on(:Visa).belongs_to :visa, resource: resource
          end
        end
      end

      it "works" do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.credit_card).to be_a(PORO::Visa)
        expect(data.credit_card.id).to be_present
        expect(data.credit_card.number).to eq(123456)
        expect(data.credit_card_type).to eq(:Visa)
      end

      context "when unknown jsonapi type" do
        let(:jsonapi_type) { "foos" }

        it "raises helpful error" do
          expect {
            klass.build(payload).save
          }.to raise_error(Graphiti::Errors::PolymorphicSideloadTypeNotFound)
        end
      end
    end

    context "when multiple levels" do
      let(:payload) do
        {
          data: {
            type: "employees",
            attributes: {first_name: "Jane"},
            relationships: {
              positions: {
                data: [{
                  type: "positions",
                  'temp-id': "abc123",
                  method: "create"
                }]
              }
            }
          },
          included: [
            {
              type: "positions",
              'temp-id': "abc123",
              attributes: {title: "mytitle"},
              relationships: {
                department: {
                  data: {
                    type: "departments",
                    'temp-id': "abc456",
                    method: "create"
                  }
                }
              }
            },
            {
              type: "departments",
              'temp-id': "abc456",
              attributes: {name: "mydept"}
            }
          ]
        }
      end

      let(:position_resource) do
        Class.new(PORO::PositionResource) do
          self.model = PORO::Position
          attribute :employee_id, :integer, only: [:writable]
          attribute :department_id, :integer, only: [:writable]
          attribute :title, :string

          def self.name
            "PORO::PositionResource"
          end
        end
      end

      let(:department_resource) do
        Class.new(PORO::DepartmentResource) do
          self.model = PORO::Department

          attribute :name, :string
        end
      end

      before do
        position_resource.belongs_to :department, resource: department_resource
        klass.has_many :positions, resource: position_resource
      end

      it "still works" do
        employee = klass.build(payload)
        expect(employee.save).to eq(true)
        data = employee.data
        expect(data.id).to be_present
        expect(data.positions.length).to eq(1)
        expect(data.positions[0]).to be_a(PORO::Position)
        expect(data.positions[0].id).to be_present
        expect(data.positions[0].title).to eq("mytitle")
        expect(data.positions[0].department).to be_a(PORO::Department)
        expect(data.positions[0].department.id).to be_present
        expect(data.positions[0].department.name).to eq("mydept")
      end
    end
  end
end
