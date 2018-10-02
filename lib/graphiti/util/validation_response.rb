# We need to know two things in the response of a persistence call:
#
#   * The model we just tried to persist
#   * Was the persistence successful?
#
# This object wraps those bits of data. The call is considered
# unsuccessful when it adheres to the ActiveModel#errors interface,
# and #errors is not blank. In other words, it is not successful if
# there were validation errors.
#
# @attr_reader object the object we are saving
class Graphiti::Util::ValidationResponse
  attr_reader :object

  # @param object the model instance we tried to save
  # @param deserialized_params see Base#deserialized_params
  def initialize(object, deserialized_params)
    @object = object
    @deserialized_params = deserialized_params
  end

  # Check to ensure no validation errors.
  # @return [Boolean] did the persistence call succeed?
  def success?
    all_valid?(object, relationships)
  end

  # @return [Array] the object and success state
  def to_a
    [object, success?]
  end

  def validate!
    unless success?
      raise ::Graphiti::Errors::ValidationError.new(self)
    end
    self
  end

  private

  def relationships
    if @deserialized_params
      @deserialized_params.relationships
    else
      {}
    end
  end

  def valid_object?(object)
    !object.respond_to?(:errors) ||
      (object.respond_to?(:errors) && object.errors.blank?)
  end

  def all_valid?(model, deserialized_params)
    checks = []
    checks << valid_object?(model)
    deserialized_params.each_pair do |name, payload|
      if payload.is_a?(Array)
        related_objects = model.send(name)
        related_objects.each_with_index do |r, index|
          valid = valid_object?(r)
          checks << valid

          if valid
            checks << all_valid?(r, payload[index][:relationships] || {})
          end
        end
      else
        related_object = model.send(name)
        valid = valid_object?(related_object)
        checks << valid
        if valid
          checks << all_valid?(related_object, payload[:relationships] || {})
        end
      end
    end
    checks.all? { |c| c == true }
  end
end
