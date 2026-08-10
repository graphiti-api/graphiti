# Deprecated entry point. graphiti_errors was absorbed into graphiti in 2.0 and
# graphiti required it for you in 1.x, so an explicit require left in an
# initializer or spec_helper would otherwise raise LoadError. Only the
# serializers survived. See graphiti/error_serializers/deprecated_constants.rb.
# Remove in 3.0.
require "graphiti"

Graphiti::DEPRECATOR.warn(
  'require "graphiti_errors" is no longer needed. graphiti_errors is part of graphiti as of 2.0, ' \
  "and its exception handling is replaced by rescue_registry."
)
