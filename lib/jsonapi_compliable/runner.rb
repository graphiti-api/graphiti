module JsonapiCompliable
  class Runner
    attr_reader :params
    include JsonapiCompliable::Base

    def initialize(resource_class, params)
      @resource_class = resource_class
      @params = params
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
