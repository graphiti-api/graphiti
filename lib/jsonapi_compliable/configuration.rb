# https://robots.thoughtbot.com/mygem-configure-block
module JsonapiCompliable
  class Configuration
    # @return [Boolean] Should we raise when the client requests a relationship not defined on the server?
    #   Defaults to true.
    attr_accessor :raise_on_missing_sideload

    # Set defaults
    # @api private
    def initialize
      @raise_on_missing_sideload = true
    end
  end
end
