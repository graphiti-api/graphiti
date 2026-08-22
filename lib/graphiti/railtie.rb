# Deprecated require path, kept so a leftover 1.x require does not raise.
# The railtie lives in Graphiti::Rails as of 2.0. Remove in 3.0.
require "graphiti"

Graphiti::DEPRECATOR.warn(
  'require "graphiti/railtie" is no longer needed. The railtie is part of the Rails ' \
  "integration as of 2.0, and loads with graphiti when Rails is present."
)
