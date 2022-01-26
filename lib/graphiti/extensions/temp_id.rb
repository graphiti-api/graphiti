module Graphiti
  # If the object we are serializing has the instance variable
  # +@_jsonapi_temp_id+, render +temp-id+ in the {http://jsonapi.org/format/#document-resource-identifier-objects resource identifier}
  #
  # Why? Well, when the request is a nested POST, creating the main entity as
  # well as relationships, we need some way of telling the client, "hey, the
  # object you have in memory, that you just sent to the server, has been
  # persisted and now has id X".
  #
  # +@_jsonapi_temp_id+ is set within this library. You should never have to
  # reference it directly.
  module SerializableTempId
    # Common interface for jsonapi-rb extensions
    def as_jsonapi(*)
      super.tap do |hash|
        if (temp_id = @object.instance_variable_get(:@_jsonapi_temp_id))
          hash[:'temp-id'] = temp_id
        end
      end
    end
  end
end
