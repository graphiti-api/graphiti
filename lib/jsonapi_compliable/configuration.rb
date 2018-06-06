# https://robots.thoughtbot.com/mygem-configure-block
module JsonapiCompliable
  class Configuration
    # @return [Boolean] Should we raise when the client requests a relationship not defined on the server?
    #   Defaults to true.
    attr_accessor :raise_on_missing_sideload
    # @return [Boolean] Concurrently fetch sideloads? This is *experimental* and may be removed.
    #   Defaults to false
    attr_accessor :experimental_concurrency

    # Set defaults
    # @api private
    def initialize
      @raise_on_missing_sideload = true
      @experimental_concurrency = false
    end

    # @api private
    def experimental_concurrency=(val)
      if val && !defined?(Concurrent::Promise)
        raise "You must add the concurrent-ruby gem to opt-in to experimental concurrency"
      else
        @experimental_concurrency = val
      end
    end
  end
end
