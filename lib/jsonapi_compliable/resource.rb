module JsonapiCompliable
  class Resource
    attr_reader :context

    class << self
      attr_accessor :config

      delegate :allow_sideload, to: :sideloading
      delegate :has_many, to: :sideloading
      delegate :has_one, to: :sideloading
      delegate :belongs_to, to: :sideloading
      delegate :has_and_belongs_to_many, to: :sideloading
      delegate :polymorphic_belongs_to, to: :sideloading
      delegate :polymorphic_has_many, to: :sideloading
    end

    delegate :sideload, to: :sideloading

    def self.inherited(klass)
      klass.config = Util::Hash.deep_dup(self.config)
    end

    def self.sideloading
      @sideloading ||= Sideload.new(:base, resource: self)
    end

    def self.sideload_whitelist(whitelist)
      config[:sideload_whitelist] = JSONAPI::IncludeDirective.new(whitelist).to_hash
    end

    def self.allow_filter(name, *args, &blk)
      opts = args.extract_options!
      aliases = [name, opts[:aliases]].flatten.compact
      config[:filters][name.to_sym] = {
        aliases: aliases,
        if: opts[:if],
        filter: blk
      }
    end

    def self.allow_stat(symbol_or_hash, &blk)
      dsl = Stats::DSL.new(config[:adapter], symbol_or_hash)
      dsl.instance_eval(&blk) if blk
      config[:stats][dsl.name] = dsl
    end

    def self.default_filter(name, &blk)
      config[:default_filters][name.to_sym] = {
        filter: blk
      }
    end

    def self.sort(&blk)
      config[:sorting] = blk
    end

    def self.paginate(&blk)
      config[:pagination] = blk
    end

    def self.extra_field(name, &blk)
      config[:extra_fields][name] = blk
    end

    def self.use_adapter(klass)
      config[:adapter] = klass.new
    end

    def self.default_sort(val)
      config[:default_sort] = val
    end

    def self.type(value = nil)
      config[:type] = value
    end

    def self.default_page_number(val)
      config[:default_page_number] = val
    end

    def self.default_page_size(val)
      config[:default_page_size] = val
    end

    def self.config
      @config ||= begin
        {
          sideload_whitelist: {},
          filters: {},
          default_filters: {},
          extra_fields: {},
          stats: {},
          sorting: nil,
          pagination: nil,
          adapter: Adapters::Abstract.new
        }
      end
    end

    def with_context(object, namespace = nil)
      begin
        prior = context
        @context = { object: object, namespace: namespace }
        yield
      ensure
        @context = prior
      end
    end

    def context
      @context || {}
    end

    def build_scope(base, query, opts = {})
      Scope.new(base, self, query, opts)
    end

    def association_names
      @association_names ||= begin
        if sideloading
          Util::Hash.keys(sideloading.to_hash[:base])
        else
          []
        end
      end
    end

    def allowed_sideloads(namespace = nil)
      return {} unless sideloading

      namespace ||= context[:namespace]
      sideloads = sideloading.to_hash[:base]
      if !sideload_whitelist.empty? && namespace
        sideloads = Util::IncludeParams.scrub(sideloads, sideload_whitelist[namespace])
      end
      sideloads
    end

    def stat(attribute, calculation)
      stats_dsl = stats[attribute] || stats[attribute.to_sym]
      raise Errors::StatNotFound.new(attribute, calculation) unless stats_dsl
      stats_dsl.calculation(calculation)
    end

    def sideloading
      self.class.sideloading
    end

    def default_sort
      self.class.config[:default_sort] || [{ id: :asc }]
    end

    def default_page_number
      self.class.config[:default_page_number] || 1
    end

    def default_page_size
      self.class.config[:default_page_size] || 20
    end

    def type
      self.class.config[:type] || :undefined_jsonapi_type
    end

    def filters
      self.class.config[:filters]
    end

    def sorting
      self.class.config[:sorting]
    end

    def stats
      self.class.config[:stats]
    end

    def pagination
      self.class.config[:pagination]
    end

    def extra_fields
      self.class.config[:extra_fields]
    end

    def sideload_whitelist
      self.class.config[:sideload_whitelist]
    end

    def default_filters
      self.class.config[:default_filters]
    end

    def adapter
      self.class.config[:adapter]
    end

    def resolve(scope)
      adapter.resolve(scope)
    end
  end
end
