module Graphiti
  class Schema
    attr_reader :resources

    def self.generate(resources = nil)
      # TODO: Maybe handle this in graphiti-rails
      ::Rails.application.eager_load! if defined?(::Rails)
      resources ||= Graphiti.resources.reject(&:abstract_class?)
      resources.reject! { |r| r.name.nil? }

      new(resources).generate
    end

    def self.generate!(resources = nil)
      schema = generate(resources)

      if ENV["FORCE_SCHEMA"] != "true" && File.exist?(Graphiti.config.schema_path)
        old = JSON.parse(File.read(Graphiti.config.schema_path))
        errors = Graphiti::SchemaDiff.new(old, schema).compare
        return errors if errors.any?
      end
      FileUtils.mkdir_p(Graphiti.config.schema_path.to_s.gsub("/schema.json", ""))
      File.write(Graphiti.config.schema_path, JSON.pretty_generate(schema))
      []
    end

    def initialize(resources)
      @resources = resources.sort_by(&:name)
      @remote_resources = @resources.select(&:remote?)
      @local_resources = @resources - @remote_resources
    end

    def generate
      {
        resources: generate_resources,
        endpoints: generate_endpoints,
        types: generate_types
      }
    end

    private

    def generate_types
      {}.tap do |types|
        Graphiti::Types.map.sort.each_entry do |name, config|
          types[name] = config.slice(:kind, :description)
        end
      end
    end

    def generate_endpoints
      {}.tap do |endpoints|
        @resources.each do |r|
          next if r.remote?

          r.endpoints.each do |e|
            actions = {}
            e[:actions].each do |a|
              next unless (ctx = context_for(e[:full_path], a))

              existing = endpoints[e[:full_path]]
              if existing && (config = existing[:actions][a])
                raise Errors::ResourceEndpointConflict.new \
                  e[:full_path], a, r.name, config[:resource]
              end

              actions[a] = {resource: r.name}
              if (allowlist = ctx.sideload_allowlist)
                if allowlist[a]
                  actions[a].merge!(sideload_allowlist: allowlist[a])
                end
              end
            end

            unless actions.empty?
              endpoints[e[:full_path]] ||= {actions: {}}
              endpoints[e[:full_path]][:actions].merge!(actions)
            end
          end
        end
      end
    end

    def context_for(path, action)
      Graphiti.config.context_for_endpoint.call(path.to_s, action)
    end

    def generate_resources
      arr = @local_resources.map { |r|
        config = {
          name: r.name,
          type: r.type.to_s,
          graphql_entrypoint: r.graphql_entrypoint.to_s,
          description: r.description,
          attributes: attributes(r),
          extra_attributes: extra_attributes(r),
          sorts: sorts(r),
          filters: filters(r),
          relationships: relationships(r),
          stats: stats(r)
        }

        if r.grouped_filters.any?
          config[:filter_group] = r.grouped_filters
        end

        if r.default_sort
          default_sort = r.default_sort.map { |s|
            {s.keys.first.to_s => s.values.first.to_s}
          }
          config[:default_sort] = default_sort
        end

        if r.default_page_size
          config[:default_page_size] = r.default_page_size
        end

        if r.polymorphic? && !r.polymorphic_child?
          config[:polymorphic] = true
          config[:children] = r.children.map(&:name)
        end

        config
      }

      arr |= @remote_resources.map { |r|
        {
          name: r.name,
          description: r.description,
          remote: r.remote_url,
          relationships: relationships(r)
        }
      }

      arr
    end

    def attributes(resource)
      {}.tap do |attrs|
        resource.attributes.each_pair do |name, config|
          if config.values_at(:readable, :writable).any? && config[:schema]
            attrs[name] = {
              type: config[:type].to_s,
              readable: flag(config[:readable]),
              writable: flag(config[:writable]),
              description: resource.attribute_description(name)
            }
          end
        end
      end
    end

    def extra_attributes(resource)
      {}.tap do |attrs|
        resource.extra_attributes.each_pair do |name, config|
          next unless config[:schema]

          attrs[name] = {
            type: config[:type].to_s,
            readable: flag(config[:readable]),
            description: resource.attribute_description(name)
          }
        end
      end
    end

    def flag(value)
      if value.is_a?(Symbol)
        "guarded"
      else
        !!value
      end
    end

    def stats(resource)
      {}.tap do |stats|
        resource.stats.each_pair do |name, config|
          stats[name] = config.calculations.keys
        end
      end
    end

    def sorts(resource)
      {}.tap do |s|
        resource.sorts.each_pair do |name, sort|
          attr = resource.all_attributes[name]
          next unless attr[:schema]

          config = {}
          config[:only] = sort[:only] if sort[:only]
          if attr[:sortable].is_a?(Symbol)
            config[:guard] = true
          end
          s[name] = config
        end
      end
    end

    def filters(resource)
      {}.tap do |f|
        resource.filters.each_pair do |name, filter|
          next unless resource.filters[name][:schema]

          config = {
            type: filter[:type].to_s,
            operators: filter[:operators].keys.map(&:to_s)
          }

          config[:single] = true if filter[:single]
          config[:allow] = filter[:allow].map(&:to_s) if filter[:allow]
          config[:deny] = filter[:deny].map(&:to_s) if filter[:deny]
          config[:dependencies] = filter[:dependencies].map(&:to_s) if filter[:dependencies]

          attr = resource.all_attributes[name]
          if attr[:filterable].is_a?(Symbol)
            if attr[:filterable] == :required
              config[:required] = true
            else
              config[:guard] = true
            end
          end
          if filter[:required] # one-off filter, not attribute
            config[:required] = true
          end
          f[name] = config
        end
      end
    end

    def filter_group(resource)
      resource.config[:grouped_filters]
    end

    def relationships(resource)
      {}.tap do |r|
        resource.sideloads.each_pair do |name, config|
          schema = {type: config.type.to_s, description: config.description}
          if config.type == :polymorphic_belongs_to
            schema[:resources] = config.children.values
              .map(&:resource).map(&:class).map(&:name)
            schema[:parent_resource] = config.parent_resource.class.name
          else
            schema[:resource] = config.resource.class.name
          end

          if config.single?
            schema[:single] = true
          end

          r[name] = schema
        end
      end
    end
  end
end
