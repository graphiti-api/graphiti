require "graphiti_spec_helpers/rspec"

RSpec.describe "deprecated constants" do
  def silenced
    Graphiti::DEPRECATOR.silence { yield }
  end

  it "resolves to Graphiti::SpecHelpers" do
    # Compared inside the block. The matcher would otherwise touch the proxy
    # after silencing has ended.
    expect(silenced { GraphitiSpecHelpers == Graphiti::SpecHelpers }).to eq(true)
  end

  it "resolves nested constants" do
    expect(silenced { GraphitiSpecHelpers::RSpec }).to eq(Graphiti::SpecHelpers::RSpec)
    expect(silenced { GraphitiSpecHelpers::Sugar }).to eq(Graphiti::SpecHelpers::Sugar)
    expect(silenced { GraphitiSpecHelpers::Node }).to eq(Graphiti::SpecHelpers::Node)
    expect(silenced { GraphitiSpecHelpers::Errors::NoSideloads })
      .to eq(Graphiti::SpecHelpers::Errors::NoSideloads)
  end

  it "can still be included" do
    klass = silenced { Class.new { include GraphitiSpecHelpers } }

    expect(klass.ancestors).to include(Graphiti::SpecHelpers::Helpers)
  end

  # The bare constant just hands back the proxy. It is resolving through it
  # that reports the deprecation.
  it "warns when used" do
    expect(Graphiti::DEPRECATOR).to receive(:warn).at_least(:once).and_return(nil)

    GraphitiSpecHelpers::Node
  end

  describe "Graphiti::SpecHelpers::Sugar" do
    it "warns on include but the aliases still work" do
      expect(Graphiti::DEPRECATOR).to receive(:warn).once.and_return(nil)

      klass = Class.new {
        include Graphiti::SpecHelpers::Sugar

        def jsonapi_data
          "data"
        end

        def jsonapi_errors
          "errors"
        end
      }
      instance = klass.new

      expect(instance.d).to eq("data")
      expect(instance.errors).to eq("errors")
    end
  end

  describe "the bare shared context names" do
    it "are still registered alongside the graphiti-prefixed ones" do
      registry = ::RSpec.world.shared_example_group_registry.send(:shared_example_groups)[:main]

      expect(registry.keys).to include(
        "graphiti resource testing", "resource testing",
        "graphiti remote api", "remote api"
      )
    end
  end

  describe "the graphiti_errors serializers" do
    {
      "GraphitiErrors::Validation::Serializer" => Graphiti::ErrorSerializers::Validation,
      "GraphitiErrors::InvalidRequest::Serializer" => Graphiti::ErrorSerializers::InvalidRequest,
      "GraphitiErrors::ConflictRequest::Serializer" => Graphiti::ErrorSerializers::ConflictRequest,
      "GraphitiErrors::Serializers::Validation" => Graphiti::ErrorSerializers::Validation
    }.each do |old_name, target|
      it "resolves #{old_name}" do
        resolved = silenced { Object.const_get(old_name) == target }

        expect(resolved).to eq(true)
      end
    end

    # These proxies are leaves. Naming one hands back the proxy, and it is
    # calling through it that reports the deprecation.
    it "warns when used" do
      expect(Graphiti::DEPRECATOR).to receive(:warn).at_least(:once).and_return(nil)

      GraphitiErrors::Validation::Serializer.new(Object.new)
    end

    # The mixin and its exception handlers are replaced by rescue_registry, not
    # renamed, so there is nothing for them to point at.
    it "does not resurrect the rest of GraphitiErrors" do
      expect(GraphitiErrors).to_not respond_to(:disable!)
      expect(defined?(GraphitiErrors::ExceptionHandler)).to be_nil
    end
  end

  describe "GraphitiContextProxy" do
    it "resolves to Graphiti::SpecHelpers::ContextProxy" do
      resolved = silenced { GraphitiContextProxy == Graphiti::SpecHelpers::ContextProxy }

      expect(resolved).to eq(true)
    end
  end

  describe "include GraphitiErrors" do
    it "raises with the replacement rather than doing nothing" do
      expect {
        Class.new { include GraphitiErrors }
      }.to raise_error(/include Graphiti::Rails::Controller/)
    end
  end

  describe "deprecated require paths" do
    {
      "graphiti_spec_helpers" => "Graphiti::SpecHelpers",
      "graphiti_errors" => "Graphiti::ErrorSerializers::Validation"
    }.each do |path, still_available|
      it "#{path.inspect} still loads" do
        expect { silenced { require path } }.to_not raise_error
        expect(Object.const_defined?(still_available)).to eq(true)
      end
    end
  end
end
