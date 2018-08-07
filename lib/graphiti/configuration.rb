# https://robots.thoughtbot.com/mygem-configure-block
module Graphiti
  class Configuration
    # @return [Boolean] Should we raise when the client requests a relationship not defined on the server?
    #   Defaults to true.
    attr_accessor :raise_on_missing_sideload
    # @return [Boolean] Concurrently fetch sideloads?
    #   Defaults to false OR if classes are cached (Rails-only)
    attr_accessor :concurrency

    attr_accessor :respond_to
    attr_accessor :context_for_endpoint
    attr_accessor :schema_path
    attr_accessor :links_on_demand

    # Set defaults
    # @api private
    def initialize
      @raise_on_missing_sideload = true
      @concurrency = false
      @respond_to = [:json, :jsonapi, :xml]
      @links_on_demand = false

      if defined?(::Rails)
        @schema_path = "#{::Rails.root}/public/schema.json"
      end
    end

    def schema_path
      @schema_path ||= raise('No schema_path defined! Set Graphiti.config.schema_path to save your schema.')
    end
  end
end
