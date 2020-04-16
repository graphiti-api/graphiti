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
    attr_accessor :links_on_demand
    attr_accessor :pagination_links_on_demand
    attr_accessor :pagination_links
    attr_accessor :typecast_reads

    attr_reader :debug, :debug_models

    attr_writer :schema_path

    # Set defaults
    # @api private
    def initialize
      @raise_on_missing_sideload = true
      @concurrency = false
      @respond_to = [:json, :jsonapi, :xml]
      @links_on_demand = false
      @pagination_links_on_demand = false
      @pagination_links = false
      @typecast_reads = true
      self.debug = ENV.fetch("GRAPHITI_DEBUG", true)
      self.debug_models = ENV.fetch("GRAPHITI_DEBUG_MODELS", false)

      # FIXME: Don't duplicate graphiti-rails efforts
      if defined?(::Rails.root) && (root = ::Rails.root)
        config_file = root.join(".graphiticfg.yml")
        if config_file.exist?
          cfg = YAML.load_file(config_file)
          @schema_path = root.join("public#{cfg["namespace"]}/schema.json")
        else
          @schema_path = root.join("public/schema.json")
        end

        if (logger = ::Rails.logger)
          self.debug = logger.level.zero? && debug
          Graphiti.logger = logger
        end
      end
    end

    def schema_path
      @schema_path ||= raise("No schema_path defined! Set Graphiti.config.schema_path to save your schema.")
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
      original = send(key)
      send(:"#{key}=", value)
      yield
    ensure
      send(:"#{key}=", original)
    end
  end

  msg = "Use graphiti-rails's `config.graphiti.respond_to_formats`"
  DEPRECATOR.deprecate_methods(Configuration, respond_to: msg, "respond_to=": msg)
end
