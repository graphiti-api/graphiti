# Deprecated entry point. graphiti required this path itself in 1.x, so an
# explicit require left behind would otherwise raise LoadError. Remove in 3.0.
require "graphiti/rails"

Graphiti::DEPRECATOR.warn(
  'require "graphiti/responders" is deprecated. Use "graphiti/rails" and include ' \
  "Graphiti::Rails::Responders."
)
