# Deprecated entry point. The spec helpers moved under Graphiti::SpecHelpers
# when the graphiti_spec_helpers gem was absorbed into graphiti in 2.0. This
# keeps `require "graphiti_spec_helpers"` and the old constant working.
# Remove in 3.0.
require "graphiti/spec_helpers"

GraphitiSpecHelpers = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(
  "GraphitiSpecHelpers",
  "Graphiti::SpecHelpers",
  Graphiti::DEPRECATOR
)
