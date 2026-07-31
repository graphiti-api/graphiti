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

  describe "the bare shared context names" do
    it "are still registered alongside the graphiti-prefixed ones" do
      registry = ::RSpec.world.shared_example_group_registry.send(:shared_example_groups)[:main]

      expect(registry.keys).to include(
        "graphiti resource testing", "resource testing",
        "graphiti remote api", "remote api"
      )
    end
  end

  describe "GraphitiContextProxy" do
    it "resolves to Graphiti::SpecHelpers::ContextProxy" do
      resolved = silenced { GraphitiContextProxy == Graphiti::SpecHelpers::ContextProxy }

      expect(resolved).to eq(true)
    end
  end

  describe "the deprecated require path" do
    it "still loads" do
      expect { silenced { require "graphiti_spec_helpers" } }.to_not raise_error
      expect(Object.const_defined?("Graphiti::SpecHelpers")).to eq(true)
    end
  end
end
