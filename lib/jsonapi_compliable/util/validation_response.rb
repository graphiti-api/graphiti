class JsonapiCompliable::Util::ValidationResponse
  attr_reader :object

  def initialize(object, deserialized_params)
    @object = object
    @deserialized_params = deserialized_params
  end

  def success?
    if object.respond_to?(:errors)
      object.errors.blank?
    else
      true
    end
  end

  def to_a
    [object, success?]
  end
end
