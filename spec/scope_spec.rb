require "spec_helper"

RSpec.describe Graphiti::Scope do
  let(:object) { double.as_null_object }
  let(:params) { {} }
  let(:query) { Graphiti::Query.new(resource, params) }
  let(:instance) { described_class.new(object, resource, query) }

  let(:resource) do
    Class.new(PORO::EmployeeResource) {
      self.default_page_size = 1
    }.new
  end
  let(:results) { [] }

  before do
    allow(resource).to receive(:resolve) { results }
  end

  describe "#resolve" do
    it "resolves via resource" do
      # object gets modified in the Scope's constructor
      objekt = instance.instance_variable_get(:@object)
      expect(resource).to receive(:resolve).with(objekt).and_return(objekt)
      instance.resolve
    end

    it "returns results" do
      expect(instance.resolve).to eq([])
    end

    context "when sideloading" do
      let(:sideload) { double(shared_remote?: false, name: :positions) }
      let(:results) { [double.as_null_object] }

      before do
        params[:include] = {positions: {}}
        objekt = instance.instance_variable_get(:@object)
        allow(resource).to receive(:resolve).with(objekt) { results }
      end

      context "when the requested sideload exists on the resource" do
        before do
          allow(resource.class).to receive(:sideload).with(:positions) { sideload }
        end

        it "resolves the sideload" do
          expect(sideload).to receive(:future_resolve)
            .with(results, query.sideloads[:positions], resource) { Concurrent::Promises.future {} }
          instance.resolve
        end

        context "but no parents were found" do
          let(:results) { [] }

          it "does not resolve the sideload" do
            expect(sideload).to_not receive(:resolve)
            instance.resolve
          end
        end
      end

      context "with concurrency" do
        let(:position_resource) do
          Class.new(PORO::PositionResource) do
            self.default_page_size = 1
          end.new
        end

        before do
          allow(resource.class).to receive(:sideload).with(:positions) { sideload }
          allow(position_resource).to receive(:resolve) { results }
          allow(position_resource.adapter).to receive(:close)

          allow(sideload).to receive(:future_resolve) do |_results, q, _parent_resource|
            described_class.new(double.as_null_object, position_resource, q).future_resolve
          end
        end

        context "when Graphiti.config.concurrency is true" do
          before do
            allow(Graphiti.config).to receive(:concurrency).and_return(true)
          end

          context "when there are available threads" do
            before do
              stub_const(
                "Graphiti::Scope::GLOBAL_THREAD_POOL_EXECUTOR",
                Concurrent::Promises.delay do
                  Concurrent::ThreadPoolExecutor.new(min_threads: 2, max_threads: 2, fallback_policy: :caller_runs)
                end
              )
            end

            it "closes db connections on the same thread as opened" do
              resolve_thread = nil
              close_thread = nil

              expect(position_resource).to receive(:resolve) do
                resolve_thread = Thread.current.object_id
                results
              end
              expect(position_resource.adapter).to receive(:close) do
                close_thread = Thread.current.object_id
                nil
              end

              instance.resolve

              expect(resolve_thread).not_to eq(Thread.current.object_id)
              expect(resolve_thread).to eq(close_thread)
            end

            it "does not close parent db connections" do
              expect(resource.adapter).not_to receive(:close)
              instance.resolve
            end
          end
        end

        context "when Graphiti.config.concurrency is false" do
          before do
            allow(Graphiti.config).to receive(:concurrency).and_return(false)
          end

          it "does not close db connections" do
            expect(position_resource.adapter).not_to receive(:close)
            expect(resource.adapter).not_to receive(:close)
            instance.resolve
          end
        end
      end

      context "when 0 results requested" do
        before do
          allow(query).to receive(:zero_results?) { true }
        end

        it "returns empty array" do
          expect(instance.resolve).to eq([])
        end
      end
    end

    describe "#resolve_sideloads" do
      let(:sideload) { double("positions", shared_remote?: false, name: :positions) }
      let(:results) { [double.as_null_object] }
      let(:params) { {include: {positions: {}}} }

      before do
        objekt = instance.instance_variable_get(:@object)
        allow(resource).to receive(:resolve).with(objekt) { results }
      end

      context "when the requested sideload exists on the resource" do
        before do
          allow(resource.class).to receive(:sideload).with(:positions) { sideload }
        end

        it "resolves the sideload" do
          expect(sideload).to receive(:future_resolve)
            .with(results, query.sideloads[:positions], resource) { Concurrent::Promises.future {} }
          instance.resolve_sideloads(results)
        end

        context "with concurrency" do
          let(:before_sideload) { double("BeforeSideload", call: nil) }

          before { allow(Graphiti.config).to receive(:concurrency).and_return(true) }
          before { allow(Graphiti.config).to receive(:before_sideload).and_return(before_sideload) }
          before do
            stub_const(
              "Graphiti::Scope::GLOBAL_THREAD_POOL_EXECUTOR",
              Concurrent::Promises.delay do
                Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: 1, fallback_policy: :caller_runs)
              end
            )
          end

          it "calls configiration.before_sideload with context" do
            Graphiti.context[:tenant_id] = 1
            allow(sideload).to receive(:future_resolve) { Concurrent::Promises.future {} }
            expect(before_sideload).to receive(:call).with(hash_including(tenant_id: 1))
            instance.resolve_sideloads(results)
          end

          it "resolves sideloads concurrently with the threadpool" do
            allow(sideload).to receive(:future_resolve) { Concurrent::Promises.future {} }
            expect(Concurrent::Promises).to receive(:future_on).with(:io).and_call_original
            expect(Concurrent::Promises).to receive(:future_on).with(an_instance_of(Concurrent::ThreadPoolExecutor), any_args).and_call_original.once
            instance.resolve_sideloads(results)
          end

          context "with nested sideloads greater than Graphiti.config.concurrency_max_threads" do
            let(:params) { {include: {positions: {department: {}}}} }
            let(:position_resource) do
              Class.new(PORO::PositionResource) do
                self.default_page_size = 1
              end.new
            end
            let(:department_resource) do
              Class.new(PORO::DepartmentResource) do
                self.default_page_size = 1
              end.new
            end
            let(:department_sideload) { double("department", shared_remote?: false, name: :department) }
            let(:position_results) { double("positions").as_null_object }

            before do
              allow(position_resource).to receive(:resolve) { position_results }
              allow(position_resource.class).to receive(:sideload).with(:department) { department_sideload }
              allow(department_resource).to receive(:resolve) { double("department").as_null_object }
              allow(department_resource.class).to receive(:sideload).with(:positions) { department_positions_sideload }

              # make resolve just load the sideloads
              allow(sideload).to receive(:future_resolve) do |_results, q, _parent_resource|
                described_class.new(double.as_null_object, position_resource, q).future_resolve
              end

              allow(department_sideload).to receive(:future_resolve) do |_results, q, _parent_resource|
                described_class.new(double.as_null_object, department_resource, q).future_resolve
              end
            end

            it "does not deadlock" do
              expect { instance.resolve_sideloads(results) }.not_to raise_error
            end

            it "flattens the nested sideload promises" do
              expect(instance.resolve_sideloads(results)).to contain_exactly(position_results)
            end
          end

          context "parent thread locals" do
            it "are accessible to the sideloading thread from the threadpool" do
              Thread.current[:foo] = "bar"

              allow(sideload).to receive(:future_resolve) do
                expect(Thread.current[:foo]).to eq("bar")
                Concurrent::Promises.fulfilled_future({})
              end
              instance.resolve_sideloads(results)

              expect(Thread.current[:foo]).to eq("bar")
            ensure
              Thread.current[:foo] = nil
            end
          end

          if Fiber.respond_to?(:[])
            context "parent fiber locals" do
              it "are accessible to the sideloading thread from the threadpool" do
                # Start the thread pool first
                #
                # Fiber storage is inherited from the parent thread so we
                # need to start the thread pool first so the thread does
                # not inherit the Fiber[:foo] from the main thread.
                allow(sideload).to receive(:future_resolve) { Concurrent::Promises.fulfilled_future({}) }
                instance.resolve_sideloads(results)

                Fiber[:foo] = "bar"

                allow(sideload).to receive(:future_resolve) do
                  expect(Fiber[:foo]).to eq("bar")
                  Concurrent::Promises.fulfilled_future({})
                end
                instance.resolve_sideloads(results)

                expect(Fiber[:foo]).to eq("bar")
              ensure
                Fiber[:foo] = nil
              end
            end
          end
        end

        context "without concurrency" do
          before { allow(Graphiti.config).to receive(:concurrency).and_return(false) }

          it "does not close db connection" do
            allow(sideload).to receive(:future_resolve) { Concurrent::Promises.future {} }

            expect(resource.adapter).not_to receive(:close)
            instance.resolve_sideloads(results)
          end

          it "does not clear thread locals" do
            Thread.current[:foo] = "bar"

            allow(sideload).to receive(:future_resolve) { Concurrent::Promises.fulfilled_future({}) }
            instance.resolve_sideloads(results)

            expect(Thread.current[:foo]).to eq("bar")
          end

          if Fiber.respond_to?(:[])
            it "does not clear fiber locals" do
              Fiber[:foo] = "bar"

              allow(sideload).to receive(:future_resolve) { Concurrent::Promises.fulfilled_future({}) }
              instance.resolve_sideloads(results)

              expect(Fiber[:foo]).to eq("bar")
            end
          end
        end

        context "but no parents were found" do
          let(:results) { [] }

          it "does not resolve the sideload" do
            expect(sideload).to_not receive(:resolve)
            instance.resolve_sideloads(results)
          end
        end

        context "when the first sideload errors" do
          before do
            allow(sideload).to receive(:future_resolve) do
              Concurrent::Promises.future { raise "danger will robinson!" }
            end
          end

          it "raises the error" do
            expect { instance.resolve_sideloads(results) }.to raise_error("danger will robinson!")
          end
        end

        context "when another sideload errors" do
          let(:sideload_2) { double("visas", shared_remote?: false, name: :visas) }
          let(:params) { {include: {positions: {}, visas: {}}} }

          before do
            allow(resource.class).to receive(:sideload).with(:visas) { sideload_2 }
            allow(sideload).to receive(:future_resolve) { Concurrent::Promises.future {} }
            allow(sideload_2).to receive(:future_resolve) { Concurrent::Promises.future { raise "sideload_2" } }
          end

          it "raises the error" do
            expect { instance.resolve_sideloads(results) }.to raise_error("sideload_2")
          end
        end

        context "when multiple sideloads error" do
          let(:sideload_2) { double("visas", shared_remote?: false, name: :visas) }
          let(:params) { {include: {positions: {}, visas: {}}} }

          before do
            allow(resource.class).to receive(:sideload).with(:visas) { sideload_2 }
            allow(sideload).to receive(:future_resolve) { Concurrent::Promises.future { raise "sideload" } }
            allow(sideload_2).to receive(:future_resolve) { Concurrent::Promises.future { raise "sideload_2" } }
          end

          it "raises the first error" do
            expect { instance.resolve_sideloads(results) }.to raise_error("sideload")
          end
        end
      end
    end

    describe "cache_key" do
      let(:employee1) {
        time = Time.parse("2022-06-24 16:36:00.000000000 -0500")
        double(cache_key: "employee/1", cache_key_with_version: "employee/1-#{time.to_i}", updated_at: time).as_null_object
      }

      let(:employee2) {
        time = Time.parse("2022-06-24 16:37:00.000000000 -0500")
        double(cache_key: "employee/2", cache_key_with_version: "employee/2-#{time.to_i}", updated_at: time).as_null_object
      }

      it "generates a stable key" do
        instance1 = described_class.new(employee1, resource, query)
        instance2 = described_class.new(employee1, resource, query)

        expect(instance1.cache_key).to be_present
        expect(instance1.cache_key).to eq(instance2.cache_key)
      end

      it "only caches off of the scoped object " do
        instance1 = described_class.new(employee1, resource, query)
        instance2 = described_class.new(employee1, resource, Graphiti::Query.new(resource, {extra_fields: {positions: ["foo"]}}))

        expect(instance1.cache_key).to be_present
        expect(instance2.cache_key).to be_present
        expect(instance1.cache_key).to eq(instance2.cache_key)

        expect(instance1.cache_key_with_version).to be_present
        expect(instance2.cache_key_with_version).to be_present
        expect(instance1.cache_key_with_version).to eq(instance2.cache_key_with_version)
      end

      it "generates a different key with a different scope query" do
        instance1 = described_class.new(employee1, resource, query)
        instance2 = described_class.new(employee2, resource, query)
        expect(instance1.cache_key).to be_present
        expect(instance2.cache_key).to be_present
        expect(instance1.cache_key).not_to eq(instance2.cache_key)

        expect(instance1.cache_key_with_version).to be_present
        expect(instance2.cache_key_with_version).to be_present
        expect(instance1.cache_key_with_version).not_to eq(instance2.cache_key)
      end
    end

    describe ".global_thread_pool_executor" do
      it "memoizes the thread pool executor" do
        one = described_class.global_thread_pool_executor
        two = described_class.global_thread_pool_executor
        expect(one).to eq(two)
      end
    end
  end
end
