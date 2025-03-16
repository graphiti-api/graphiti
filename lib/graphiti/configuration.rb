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
    attr_accessor :raise_on_missing_sidepost
    attr_accessor :before_sideload
    attr_accessor :deduplicate_entities

    attr_reader :debug, :debug_models
    attr_reader :uri_decoder

    attr_writer :schema_path
    attr_writer :cache_rendering

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
      @raise_on_missing_sidepost = true
      @cache_rendering = false
      self.debug = ENV.fetch("GRAPHITI_DEBUG", true)
      self.debug_models = ENV.fetch("GRAPHITI_DEBUG_MODELS", false)

      @uri_decoder = infer_uri_decoder

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
          self.debug = logger.debug? && debug
          Graphiti.logger = logger
        end
      end
    end

    def cache_rendering?
      use_caching = @cache_rendering && Graphiti.cache.respond_to?(:fetch)

      use_caching.tap do |use|
        if @cache_rendering && !Graphiti.cache&.respond_to?(:fetch)
          raise "You must configure a cache store in order to use cache_rendering. Set Graphiti.cache = Rails.cache, for example."
        end
      end
    end

    def deduplicated_rendering?
      if @deduplicate_entities
        raise "Deduplicated rendering is not compatible with concurrent fetching" if @concurrency

        return true
      end

      false
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

    def uri_decoder=(decoder)
      unless decoder.respond_to?(:call)
        raise "uri_decoder must respond to `call`."
      end

      @uri_decoder = decoder
    end

    private

    def infer_uri_decoder
      if defined?(::ActionDispatch::Journey::Router::Utils)
        # available in all supported versions of Rails.
        # This method should be preferred for comparing URI path segments
        # to params, as it is the exact decoder used in the Rails router.
        @uri_decoder = ::ActionDispatch::Journey::Router::Utils.method(:unescape_uri)
      elsif URI.respond_to?(:decode_uri_component)
        # available in Ruby >= 3.2
        @uri_decoder = URI.method(:decode_uri_component)
      end
    rescue => e
      Kernel.warn("Error inferring Graphiti uri_decoder: #{e}")
    ensure
      # fallback
      @uri_decoder ||= :itself.to_proc
    end
  end

  msg = "Use graphiti-rails's `config.graphiti.respond_to_formats`"
  DEPRECATOR.deprecate_methods(Configuration, respond_to: msg, "respond_to=": msg)
end
