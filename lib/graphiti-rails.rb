# Deprecated entry point. The graphiti-rails gem was absorbed into graphiti in
# 2.0, and its integration loads automatically whenever Rails is defined, so
# this require is no longer needed. It is kept so an explicit
# `require "graphiti-rails"` left over from 1.x does not raise. Remove in 3.0.
require "graphiti"
require "graphiti/rails"

Graphiti::DEPRECATOR.warn(
  'require "graphiti-rails" is no longer needed. graphiti-rails is part of graphiti as of 2.0, ' \
  "and the Rails integration is loaded for you when Rails is present."
)
