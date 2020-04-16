module Graphiti
  class Resource
    module Configuration
      extend ActiveSupport::Concern

      DEFAULT_MAX_PAGE_SIZE = 1_000

      module Overrides
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

        def type=(val)
          val = val&.to_sym
          if (val = super)
            serializer.type(val)
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
          :default_page_size,
          :default_sort,
          :max_page_size,
          :attributes_readable_by_default,
          :attributes_writable_by_default,
          :attributes_sortable_by_default,
          :attributes_filterable_by_default,
          :attributes_schema_by_default,
          :relationships_readable_by_default,
          :relationships_writable_by_default,
          :filters_accept_nil_by_default,
          :filters_deny_empty_by_default

        class << self
          prepend Overrides
        end

        def self.inherited(klass)
          super
          klass.config = Util::Hash.deep_dup(config)
          klass.adapter ||= Adapters::Abstract
          klass.max_page_size ||= DEFAULT_MAX_PAGE_SIZE
          # re-assigning causes a new Class.new
          klass.serializer = (klass.serializer || klass.infer_serializer_superclass)
          klass.type ||= klass.infer_type
          default(klass, :attributes_readable_by_default, true)
          default(klass, :attributes_writable_by_default, true)
          default(klass, :attributes_sortable_by_default, true)
          default(klass, :attributes_filterable_by_default, true)
          default(klass, :attributes_schema_by_default, true)
          default(klass, :relationships_readable_by_default, true)
          default(klass, :relationships_writable_by_default, true)
          default(klass, :filters_accept_nil_by_default, false)
          default(klass, :filters_deny_empty_by_default, false)

          unless klass.config[:attributes][:id]
            klass.attribute :id, :integer_id
          end
          klass.stat total: [:count]

          if defined?(::Rails) && ::Rails.env.development?
            # Avoid adding dupe resources when re-autoloading
            Graphiti.resources.reject! { |r| r.name == klass.name }
          end
          Graphiti.resources << klass
        end
      end

      class_methods do
        def get_attr!(name, flag, opts = {})
          opts[:raise_error] = true
          get_attr(name, flag, opts)
        end

        def get_attr(name, flag, opts = {})
          defaults = {request: false}
          opts = defaults.merge(opts)
          new.get_attr(name, flag, opts)
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
          end
        end

        def infer_type
          if name.present?
            name.demodulize.gsub("Resource", "").underscore.pluralize.to_sym
          else
            :undefined_jsonapi_type
          end
        end

        def infer_model
          name&.gsub("Resource", "")&.safe_constantize
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

        def default(object, attr, value)
          prior = object.send(attr)
          unless prior || prior == false
            object.send(:"#{attr}=", value)
          end
        end
        private :default

        def config
          @config ||=
            {
              filters: {},
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
              links: {},
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
        get_attr(name, flag, options)
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
  end
end
