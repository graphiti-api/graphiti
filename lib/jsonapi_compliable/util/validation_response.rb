class JsonapiCompliable::Util::ValidationResponse
  attr_reader :object

  def initialize(object, deserialized_params)
    @object = object
    @deserialized_params = deserialized_params
  end

  def success?
    all_valid?(object, @deserialized_params.relationships)
  end

  def to_a
    [object, success?]
  end

  private

  def valid_object?(object)
    object.respond_to?(:errors) && object.errors.blank?
  end

  def all_valid?(model, deserialized_params)
    valid = true
    return false unless valid_object?(model)
    deserialized_params.each_pair do |name, payload|
      if payload.is_a?(Array)
        related_objects = model.send(name)
        related_objects.each do |r|
          valid = valid_object?(r)

          if valid
            valid = all_valid?(r, deserialized_params[:relationships] || {})
          end
        end
      else
        related_object = model.send(name)
        valid = valid_object?(related_object)
        if valid
          valid = all_valid?(related_object, deserialized_params[:relationships] || {})
        end
      end
    end
    valid
  end
end
