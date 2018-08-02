# https://robots.thoughtbot.com/mygem-configure-block
module JsonapiCompliable
  class Configuration
    # @return [Boolean] Should we raise when the client requests a relationship not defined on the server?
    #   Defaults to true.
    attr_accessor :raise_on_missing_sideload
    # @return [Boolean] Concurrently fetch sideloads?
    #   Defaults to false OR if classes are cached (Rails-only)
    attr_accessor :concurrency

    attr_accessor :respond_to

    attr_accessor :context_for_endpoint

    # Set defaults
    # @api private
    def initialize
      @raise_on_missing_sideload = true
      @concurrency = false
      @respond_to = [:json, :jsonapi, :xml]
    end
  end
end
