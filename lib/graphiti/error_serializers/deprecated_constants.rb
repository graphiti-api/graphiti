# The graphiti_errors gem was absorbed into graphiti in 2.0. Only its
# serializers survived, as Graphiti::ErrorSerializers. The rest of it (the
# GraphitiErrors controller mixin and its exception handlers) is replaced by
# rescue_registry rather than renamed, so there is deliberately nothing here to
# alias it to. A custom error renderer reaching for one of the serializers gets
# pointed at the new name instead of a bare NameError. Remove in 3.0.
module GraphitiErrors
  # `include GraphitiErrors` in ApplicationController was this gem's headline
  # usage. Including an empty module succeeds, so without this an upgraded app
  # boots clean and then serves Rails' default HTML error pages instead of
  # JSON:API ones, with nothing to indicate why.
  def self.included(klass)
    raise <<~MSG
      GraphitiErrors was merged into graphiti as of 2.0 and `include GraphitiErrors`
      no longer does anything.

      Exception handling now goes through rescue_registry. Replace it with:

        include Graphiti::Rails::Controller

      which registers Graphiti's own handlers. Your own go alongside them with
      `register_exception`, available on every controller.
    MSG
  end

  module Validation; end

  module InvalidRequest; end

  module ConflictRequest; end

  module Serializers; end
end

{
  "GraphitiErrors::Validation::Serializer" => "Graphiti::ErrorSerializers::Validation",
  "GraphitiErrors::InvalidRequest::Serializer" => "Graphiti::ErrorSerializers::InvalidRequest",
  "GraphitiErrors::ConflictRequest::Serializer" => "Graphiti::ErrorSerializers::ConflictRequest",
  # Graphiti 1.0.x referenced this spelling
  "GraphitiErrors::Serializers::Validation" => "Graphiti::ErrorSerializers::Validation"
}.each do |old_name, new_name|
  namespace, _, constant = old_name.rpartition("::")

  Object.const_get(namespace).const_set(
    constant,
    ActiveSupport::Deprecation::DeprecatedConstantProxy.new(old_name, new_name, Graphiti::DEPRECATOR)
  )
end
