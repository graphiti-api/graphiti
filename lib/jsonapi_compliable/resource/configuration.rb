module JsonapiCompliable
  class Resource
    module Configuration
      extend ActiveSupport::Concern

      module Overrides
        def serializer=(val)
          if val
            if super(Class.new(val))
              apply_attributes_to_serializer
              apply_sideloads_to_serializer
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
          if val = super
            self.serializer.type(val)
          end
        end

        def model
          klass = super
          unless klass || abstract_class?
            if klass = infer_model
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

        class_attribute :adapter,
          :model,
          :type,
          :polymorphic,
          :polymorphic_child,
          :serializer,
          :default_page_size,
          :default_sort,
          :attributes_readable_by_default,
          :attributes_writable_by_default,
          :attributes_sortable_by_default,
          :attributes_filterable_by_default,
          :relationships_readable_by_default,
          :relationships_writable_by_default

        class << self
          prepend Overrides
        end

        def self.inherited(klass)
          super
          klass.config = Util::Hash.deep_dup(config)
          klass.adapter ||= Adapters::Abstract.new
          klass.default_sort ||= []
          klass.default_page_size ||= 20
          # re-assigning causes a new Class.new
          if klass.serializer
            klass.serializer = klass.serializer
          else
            klass.serializer = JSONAPI::Serializable::Resource
          end
          klass.type ||= klass.infer_type
          default(klass, :attributes_readable_by_default, true)
          default(klass, :attributes_writable_by_default, true)
          default(klass, :attributes_sortable_by_default, true)
          default(klass, :attributes_filterable_by_default, true)
          default(klass, :relationships_readable_by_default, true)
          default(klass, :relationships_writable_by_default, true)

          unless klass.config[:attributes][:id]
            klass.attribute :id, :string
          end
        end
      end

      class_methods do
        def get_attr!(name, flag, opts = {})
          opts[:raise_error] = true
          get_attr(name, flag, opts)
        end

        def get_attr(name, flag, opts = {})
          defaults = { request: false }
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
          if @abstract_class = val
            self.serializer = nil
            self.type = nil
          end
        end

        def infer_type
          if name.present?
            name.demodulize.gsub('Resource','').underscore.pluralize.to_sym
          else
            :undefined_jsonapi_type
          end
        end

        def infer_model
          name.gsub('Resource', '').safe_constantize if name
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
              before_commit: {},
              attributes: {},
              extra_attributes: {},
              sideloads: {}
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
      end

      def get_attr!(name, flag, options = {})
        options[:raise_error] = true
        get_attr(name, flag, options)
      end

      def get_attr(name, flag, request: false, raise_error: false)
        Util::AttributeCheck.run(self, name, flag, request, raise_error)
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
