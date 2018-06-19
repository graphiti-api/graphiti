module JsonapiCompliable
  class Runner
    attr_reader :params, :verb
    include JsonapiCompliable::Base

    jsonapi resource: JsonapiCompliable::Resource

    def initialize(resource_class, params, verb: :get)
      @resource_class = resource_class
      @params = params
      @verb = verb
    end

    def jsonapi_resource
      @jsonapi_resource ||= @resource_class.new
    end

    # Typically, this is 'self' of a controller
    # We're overriding here so we can do stuff like
    #
    # JsonapiCompliable.with_context my_context, {} do
    #   Runner.new ...
    # end
    def jsonapi_context
      JsonapiCompliable.context[:object]
    end
  end
end
