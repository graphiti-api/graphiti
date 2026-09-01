# Only graphiti_errors' serializers survived the 2.0 merge. Remove in 3.0.
module GraphitiErrors
  # Including an empty module succeeds, so silence here means HTML error pages.
  def self.included(klass)
    raise <<~MSG
      GraphitiErrors merged into graphiti in 2.0 and this include does nothing. Use:

        include Graphiti::Rails::Controller

      Your own exceptions register alongside Graphiti's with `register_exception`.
      `registered_exception?` is now `RescueRegistry.handles_exception?`, and
      `handle_exception` went with the rendering. See graphiti.dev/upgrading.
    MSG
  end

  # The old global rendering toggle, most often flipped in specs.
  class << self
    def enable!
      Graphiti::DEPRECATOR.deprecation_warning("GraphitiErrors.enable!", "wrap the request in Graphiti::Rails::TestHelpers#handle_request_exceptions instead")
      test_helpers.handle_request_exceptions(true)
    end

    def disable!
      Graphiti::DEPRECATOR.deprecation_warning("GraphitiErrors.disable!", "wrap the request in Graphiti::Rails::TestHelpers#handle_request_exceptions instead")
      test_helpers.handle_request_exceptions(false)
    end

    def disabled?
      !test_helpers.handle_request_exceptions?
    end

    private

    def test_helpers
      @test_helpers ||= Object.new.extend(Graphiti::Rails::TestHelpers)
    end
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
