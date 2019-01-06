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
    attr_accessor :typecast_reads
    attr_accessor :debug
    attr_accessor :debug_models

    # Set defaults
    # @api private
    def initialize
      @raise_on_missing_sideload = true
      @concurrency = false
      @respond_to = [:json, :jsonapi, :xml]
      @links_on_demand = false
      @typecast_reads = true
      self.debug = ENV.fetch('GRAPHITI_DEBUG', true)
      self.debug_models = ENV.fetch('GRAPHITI_DEBUG_MODELS', false)

      if defined?(::Rails)
        if File.exists?("#{::Rails.root}/.graphiticfg.yml")
          cfg = YAML.load_file("#{::Rails.root}/.graphiticfg.yml")
          @schema_path = "#{::Rails.root}/public#{cfg['namespace']}/schema.json"
        else
          @schema_path = "#{::Rails.root}/public/schema.json"
        end
        self.debug = ::Rails.logger.level.zero?
        Graphiti.logger = ::Rails.logger
      end
    end

    def schema_path
      @schema_path ||= raise('No schema_path defined! Set Graphiti.config.schema_path to save your schema.')
    end

    def debug=(val)
      @debug = val
      Debugger.enabled = val
    end

    def debug_models=(val)
      @debug_models = val
      Debugger.debug_models = val
    end

    def with_option(key, value)
      begin
        original = send(key)
        send(:"#{key}=", value)
        yield
      ensure
        send(:"#{key}=", original)
      end
    end
  end
end
