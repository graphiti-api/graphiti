module Graphiti
  class Resource
    module DSL
      extend ActiveSupport::Concern

      class_methods do
        def filter(name, *args, &blk)
          name = name.to_sym
          opts = args.extract_options!
          type_override = args[0]

          if (att = (attributes[name] || extra_attributes[name]))
            # We're opting in to filtering, so force this
            # UNLESS the filter is guarded at the attribute level
            att[:filterable] = true if att[:filterable] == false

            aliases = [name, opts[:aliases]].flatten.compact
            operators = FilterOperators.build(self, att[:type], opts, &blk)

            case Graphiti::Types[att[:type]][:canonical_name]
            when :boolean
              opts[:single] = true
            when :enum
              if opts[:allow].blank?
                raise Errors::MissingEnumAllowList.new(self, name, att[:type])
              end
            end

            required = att[:filterable] == :required || !!opts[:required]
            schema = !!opts[:via_attribute_dsl] ? att[:schema] : opts[:schema] != false

            config[:filters][name.to_sym] = {
              aliases: aliases,
              name: name.to_sym,
              type: type_override || att[:type],
              allow: opts[:allow],
              deny: opts[:deny],
              single: !!opts[:single],
              dependencies: opts[:dependent],
              required: required,
              schema: schema,
              operators: operators.to_hash,
              allow_nil: opts.fetch(:allow_nil, filters_accept_nil_by_default),
              deny_empty: opts.fetch(:deny_empty, filters_deny_empty_by_default)
            }
          elsif (type = args[0])
            attribute name, type, only: [:filterable], allow: opts[:allow]
            filter(name, opts, &blk)
          else
            raise Errors::ImplicitFilterTypeMissing.new(self, name)
          end
        end

        def filter_group(filter_names, *args)
          opts = args.extract_options!

          Scoping::FilterGroupValidator.raise_unless_filter_group_requirement_valid!(self, opts[:required])

          config[:grouped_filters] = {
            names: filter_names,
            required: opts[:required]
          }
        end

        def sort_all(&blk)
          if blk
            config[:_sort_all] = blk
          else
            config[:_sort_all]
          end
        end

        def sort(name, *args, &blk)
          opts = args.extract_options!

          if get_attr(name, :sortable, raise_error: :only_unsupported)
            config[:sorts][name] = {
              proc: blk
            }.merge(opts.slice(:only))
          elsif (type = args[0])
            attribute name, type, only: [:sortable]
            sort(name, opts, &blk)
          else
            raise Errors::ImplicitSortTypeMissing.new(self, name)
          end
        end

        def paginate(&blk)
          config[:pagination] = blk
        end

        def stat(symbol_or_hash, &blk)
          dsl = Stats::DSL.new(new.adapter, symbol_or_hash)
          dsl.instance_eval(&blk) if blk
          config[:stats][dsl.name] = dsl
        end

        def default_filter(name = nil, &blk)
          name ||= :__default
          config[:default_filters][name.to_sym] = {
            filter: blk
          }
        end

        def after_graph_persist(only: [:create, :update, :destroy], &blk)
          Array(only).each do |verb|
            config[:after_graph_persist][verb] ||= []
            config[:after_graph_persist][verb] << blk
          end
        end

        def before_commit(only: [:create, :update, :destroy], &blk)
          Array(only).each do |verb|
            config[:before_commit][verb] ||= []
            config[:before_commit][verb] << blk
          end
        end

        def after_commit(only: [:create, :update, :destroy], &blk)
          Array(only).each do |verb|
            config[:after_commit][verb] ||= []
            config[:after_commit][verb] << blk
          end
        end

        def attribute(name, type, options = {}, &blk)
          raise Errors::TypeNotFound.new(self, name, type) unless Types[type]
          attribute_option(options, :readable)
          attribute_option(options, :writable)
          attribute_option(options, :sortable)
          attribute_option(options, :filterable)
          attribute_option(options, :schema, true)
          options[:type] = type
          options[:proc] = blk
          config[:attributes][name] = options
          apply_attributes_to_serializer
          options[:sortable] ? sort(name) : config[:sorts].delete(name)

          if options[:filterable]
            filter(name, allow: options[:allow], via_attribute_dsl: true)
          else
            config[:filters].delete(name)
          end
        end

        def extra_attribute(name, type, options = {}, &blk)
          raise Errors::TypeNotFound.new(self, name, type) unless Types[type]
          defaults = {
            type: type,
            proc: blk,
            readable: true,
            writable: false,
            sortable: false,
            filterable: false,
            schema: true
          }
          options = defaults.merge(options)
          attribute_option(options, :readable)
          config[:extra_attributes][name] = options
          apply_extra_attributes_to_serializer
        end

        def on_extra_attribute(name, &blk)
          if config[:extra_attributes][name]
            config[:extra_attributes][name][:hook] = blk
          else
            raise Errors::ExtraAttributeNotFound.new(self, name)
          end
        end

        def link(name, &blk)
          config[:links][name.to_sym] = blk
        end

        def all_attributes
          attributes.merge(extra_attributes)
        end

        def apply_attributes_to_serializer
          serializer.type(type)
          Util::SerializerAttributes.new(self, attributes).apply
        end
        private :apply_attributes_to_serializer

        def apply_extra_attributes_to_serializer
          Util::SerializerAttributes.new(self, extra_attributes, true).apply
        end

        def attribute_option(options, name, exclusive = false)
          if options[name] != false
            default = if (only = options[:only]) && !exclusive
              Array(only).include?(name)
            elsif (except = options[:except]) && !exclusive
              !Array(except).include?(name)
            else
              send(:"attributes_#{name}_by_default")
            end
            options[name] ||= default
          end
        end
        private :attribute_option

        def relationship_option(options, name)
          if options[name] != false
            options[name] ||= send(:"relationships_#{name}_by_default")
          end
        end
        private :relationship_option
      end
    end
  end
end
