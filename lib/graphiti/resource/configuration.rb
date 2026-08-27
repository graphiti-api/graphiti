module Graphiti
  class Resource
    module Configuration
      extend ActiveSupport::Concern

      DEFAULT_MAX_PAGE_SIZE = 1_000
      LINK_MODES = [true, false, :on_demand].freeze
      BELONGS_TO_RESOURCE_IDS_MODES = [:foreign_key, :always, :never].freeze
      BLANK_MODES = [:literal, :null, :rejected].freeze

      # Grouped for the ApplicationResource the install generator writes.
      SETTING_GROUPS = { # :nodoc:
        attributes: {
          attributes_readable_by_default: {default: true},
          attributes_writable_by_default: {default: true},
          attributes_sortable_by_default: {default: true},
          attributes_filterable_by_default: {default: true},
          attributes_schema_by_default: {default: true},
          typecast_reads: {default: true}
        },
        relationships: {
          relationships_readable_by_default: {default: true},
          relationships_writable_by_default: {default: true},
          relationship_placeholders: {default: false, note: "render placeholders for relationships with no ids and no link"},
          belongs_to_resource_ids_by_default: {
            default: :foreign_key,
            values: BELONGS_TO_RESOURCE_IDS_MODES,
            invalid: ->(klass, value) { Errors::InvalidBelongsToResourceIds.new(klass, value) }
          }
        },
        filters: {
          filter_blanks_treated_as: {
            default: :literal,
            values: BLANK_MODES,
            invalid: ->(klass, value) { Errors::InvalidFilterBlanks.new(klass, :filter_blanks_treated_as, value) }
          }
        },
        sorting: {
          default_sort: {default: nil, note: "per resource, e.g. [{id: :desc}]"}
        },
        pagination: {
          page_default_size: {default: nil, note: "unset falls back to 20"},
          page_max_size: {default: DEFAULT_MAX_PAGE_SIZE, format: "1_000"},
          page_cursors: {default: false, note: "render cursors for pagination"},
          page_links: {
            default: false,
            values: LINK_MODES,
            invalid: ->(klass, value) { Errors::InvalidLinkRendering.new(klass, :page_links, value) }
          }
        },
        endpoints: {
          validate_requests: {default: true, note: "refuse requests to undeclared endpoints"}
        },
        links: {
          relationship_links: {
            default: true,
            values: LINK_MODES,
            invalid: ->(klass, value) { Errors::InvalidLinkRendering.new(klass, :relationship_links, value) }
          },
          validate_links: {default: true, note: "refuse to render links to unroutable endpoints"}
        }
      }.freeze

      SETTINGS = SETTING_GROUPS.values.reduce(:merge).freeze # :nodoc:

      module Overrides
        SETTINGS.each_pair do |name, setting|
          next unless setting[:values]

          define_method(:"#{name}=") do |val|
            unless setting[:values].include?(val)
              raise setting[:invalid].call(self, val)
            end

            super(val)
          end
        end

        def serializer=(val)
          if val
            if super(Class.new(val))
              apply_attributes_to_serializer
            end
          else
            super
          end
        end

        def polymorphic=(klasses)
          super
          send(:prepend, Polymorphism)
        end

        def polymorphic?
          polymorphic.present?
        end

        def type=(val)
          val = val&.to_sym
          if (val = super)
            serializer.type(val)
          end
        end

        def graphql_entrypoint=(val)
          if val
            super(val.to_s.camelize(:lower).to_sym)
          else
            super
          end
        end

        # The .stat call stores a proc based on adapter
        # So if we assign a new adapter, reconfigure
        def adapter=(val)
          super
          stat total: [:count]
        end

        def remote=(val)
          super
          include ::Graphiti::Resource::Remote

          self.endpoint = {
            path: val,
            full_path: val,
            url: val,
            actions: [:index, :show]
          }
        end

        def model
          klass = super
          unless klass || abstract_class?
            if (klass = infer_model)
              self.model = klass
            else
              raise Errors::ModelNotFound.new(self)
            end
          end
          klass
        end
      end

      included do
        class << self
          attr_writer :config
        end

        class_attribute :adapter, instance_reader: false
        class_attribute :model,
          :remote,
          :remote_base_url,
          :type,
          :polymorphic,
          :polymorphic_child,
          :serializer,
          :graphql_entrypoint,
          *SETTINGS.keys

        class << self
          prepend Overrides
        end

        SETTINGS.each_pair do |name, setting|
          public_send(:"#{name}=", setting[:default])
        end

        def self.inherited(klass)
          super
          klass.config = Util::Hash.deep_dup(config)
          klass.adapter ||= Adapters::Abstract
          # re-assigning causes a new Class.new
          klass.serializer = (klass.serializer || klass.infer_serializer_superclass)
          klass.type ||= klass.infer_type
          klass.graphql_entrypoint = klass.type.to_s.pluralize.to_sym
          unless klass.config[:attributes][:id]
            klass.attribute :id, :integer_id
          end
          klass.stat total: [:count]

          # An abstract parent has no serializer for its sideloads, so the subclass applies them here.
          if abstract_class?
            klass.config[:sideloads].each_pair do |name, sideload|
              klass.apply_sideload_to_serializer(name) if klass.eagerly_apply_sideload?(sideload)
            end
          end

          if defined?(::Rails) && ::Rails.env.development?
            # Avoid adding dupe resources when re-autoloading
            Graphiti.resources.reject! { |r| r.name == klass.name }
          end
          Graphiti.resources << klass
        end
      end

      class_methods do
        # Deprecated. Both folded into filter_blanks_treated_as. Remove in 3.0.
        def filters_accept_nil_by_default
          filter_blanks_treated_as == :null
        end

        def filters_accept_nil_by_default=(val)
          self.filter_blanks_treated_as = val ? :null : :literal
        end

        def filters_deny_empty_by_default
          filter_blanks_treated_as == :rejected
        end

        def filters_deny_empty_by_default=(val)
          self.filter_blanks_treated_as = val ? :rejected : :literal
        end

        # Deprecated. Renamed to the page_ family. Remove in 3.0.
        def default_page_size
          page_default_size
        end

        def default_page_size=(val)
          self.page_default_size = val
        end

        def max_page_size
          page_max_size
        end

        def max_page_size=(val)
          self.page_max_size = val
        end

        def cursor_paginatable
          page_cursors
        end

        def cursor_paginatable=(val)
          self.page_cursors = val
        end

        def cursor_paginatable?
          !!page_cursors
        end

        def get_attr!(name, flag, opts = {})
          opts[:raise_error] = true
          get_attr(name, flag, opts)
        end

        def get_attr(name, flag, opts = {})
          defaults = {request: false}
          opts = defaults.merge(opts)
          new.get_attr(name, flag, **opts)
        end

        def abstract_class?
          !!abstract_class
        end

        def abstract_class
          @abstract_class
        end

        def abstract_class=(val)
          if (@abstract_class = val)
            self.serializer = nil
            self.type = nil
            self.graphql_entrypoint = nil
          end
        end

        def infer_type
          if name.present?
            name.demodulize.sub(/.*\KResource/, "").underscore.pluralize.to_sym
          else
            :undefined_jsonapi_type
          end
        end

        def infer_model
          name&.sub(/.*\KResource/, "")&.safe_constantize
        end

        # @api private
        def infer_serializer_superclass
          serializer_class = ::Graphiti::Serializer
          namespace = Util::Class.namespace_for(self)
          app_serializer = "#{namespace}::ApplicationSerializer"
            .safe_constantize
          app_serializer ||= "ApplicationSerializer".safe_constantize

          if app_serializer
            if app_serializer.ancestors.include?(serializer_class)
              serializer_class = app_serializer
            end
          end

          serializer_class
        end

        def config
          @config ||=
            {
              filters: {},
              grouped_filters: {},
              default_filters: {},
              stats: {},
              sort_all: nil,
              sorts: {},
              pagination: nil,
              after_graph_persist: {},
              before_commit: {},
              after_commit: {},
              attributes: {},
              extra_attributes: {},
              sideloads: {},
              callbacks: {},
              links: {}
            }
        end

        def attributes
          config[:attributes]
        end

        def extra_attributes
          config[:extra_attributes]
        end

        def all_attributes
          attributes.merge(extra_attributes)
        end

        def sideloads
          config[:sideloads]
        end

        def filters
          config[:filters]
        end

        def grouped_filters
          config[:grouped_filters]
        end

        def sorts
          config[:sorts]
        end

        def stats
          config[:stats]
        end

        def pagination
          config[:pagination]
        end

        def default_filters
          config[:default_filters]
        end

        def links
          config[:links]
        end
      end

      def get_attr!(name, flag, options = {})
        options[:raise_error] = true
        get_attr(name, flag, **options)
      end

      def get_attr(name, flag, request: false, raise_error: false)
        Util::AttributeCheck.run(self, name, flag, request, raise_error)
      end

      def adapter
        @adapter ||= self.class.adapter.new(self)
      end

      def filters
        self.class.filters
      end

      def grouped_filters
        self.class.grouped_filters
      end

      def sort_all
        self.class.sort_all
      end

      def sorts
        self.class.sorts
      end

      def stats
        self.class.stats
      end

      def pagination
        self.class.pagination
      end

      def attributes
        self.class.attributes
      end

      def extra_attributes
        self.class.extra_attributes
      end

      def all_attributes
        self.class.all_attributes
      end

      def default_filters
        self.class.default_filters
      end
    end

    blanks_msg = "Use `self.filter_blanks_treated_as` (:literal, :null, or :rejected)"
    page_msg = "Use `self.page_default_size`, `self.page_max_size` and `self.page_cursors`"
    DEPRECATOR.deprecate_methods(Configuration::ClassMethods,
      filters_accept_nil_by_default: blanks_msg,
      "filters_accept_nil_by_default=": blanks_msg,
      filters_deny_empty_by_default: blanks_msg,
      "filters_deny_empty_by_default=": blanks_msg,
      default_page_size: page_msg,
      "default_page_size=": page_msg,
      max_page_size: page_msg,
      "max_page_size=": page_msg,
      cursor_paginatable: page_msg,
      "cursor_paginatable=": page_msg,
      cursor_paginatable?: page_msg)
  end
end
