if ENV["APPRAISAL_INITIALIZED"]
  require "rails_spec_helper"
  require "graphiti/rails/rake_helpers"

  RSpec.describe "connection pool exhaustion inside a concurrent sideload" do
    include ConcurrencyHarness

    let!(:employee) { PORO::Employee.create }

    before do
      allow(Graphiti.config).to receive(:concurrency).and_return(true)
      with_thread_pool(max_threads: 2)
    end

    it "points the timeout at the sizing formula" do
      position_resource = Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end

        def resolve(_scope)
          raise ActiveRecord::ConnectionTimeoutError, "could not obtain a connection from the pool"
        end
      end
      resource_class = Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::EmployeeResource"
        end
      end
      resource_class.has_many :probe_positions, resource: position_resource, foreign_key: :employee_id

      expect {
        resource_class.all(filter: {id: employee.id}, include: "probe_positions").to_a
      }.to raise_error(ActiveRecord::ConnectionTimeoutError) { |error|
        expect(error.message).to include("could not obtain a connection")
        expect(error.message).to include("concurrency_max_threads")
        expect(error.message).to include("concurrency-pool-sizing")
      }
    end
  end

  RSpec.describe Graphiti::Rails::RakeHelpers do
    describe ".connection_pool_advisory" do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("RAILS_MAX_THREADS", 5).and_return("5")
      end

      def with_pool_size(size)
        config = ActiveRecord::Base.connection_db_config
        allow(ActiveRecord::Base).to receive(:connection_db_config)
          .and_return(instance_double(config.class, pool: size))
      end

      it "warns when the pool cannot cover web and sideload threads" do
        with_pool_size(5)

        advisory = described_class.connection_pool_advisory
        expect(advisory).to include("pool is 5")
        expect(advisory).to include("+ 1 = 10")
      end

      it "stays quiet when the pool is big enough" do
        with_pool_size(50)

        expect(described_class.connection_pool_advisory).to be_nil
      end
    end
  end
end
