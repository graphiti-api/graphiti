module JsonapiCompliable
  module SerializableTempId
    def as_jsonapi(*)
      super.tap do |hash|
        if temp_id = @object.instance_variable_get(:'@_jsonapi_temp_id')
          hash[:'temp-id'] = temp_id
        end
      end
    end
  end
end

JSONAPI::Serializable::Resource.class_eval do
  prepend JsonapiCompliable::SerializableTempId
end
