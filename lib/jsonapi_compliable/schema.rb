module JsonapiCompliable
  class Schema
    attr_reader :resources

    def self.generate(resources = nil)
      ::Rails.application.eager_load! if defined?(::Rails)
      resources ||= JsonapiCompliable.resources.reject(&:abstract_class?)
      new(resources).generate
    end

    def initialize(resources)
      @resources = resources
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
        JsonapiCompliable::Types.map.each_pair do |name, config|
          types[name] = config.slice(:kind, :description)
        end
      end
    end

    def generate_endpoints
      {}.tap do |endpoints|
        @resources.each do |r|
          r.endpoints.each do |e|
            actions = {}
            e[:actions].each do |a|
              next unless ctx = context_for(e[:path], a)

              existing = endpoints[e[:path]]
              if existing && config = existing[:actions][a]
                raise Errors::ResourceEndpointConflict.new \
                  e[:path], a, r.name, config[:resource]
              end

              actions[a] = { resource: r.name }
              if whitelist = ctx.sideload_whitelist[a]
                actions[a].merge!(sideload_whitelist: whitelist)
              end
            end

            unless actions.empty?
              endpoints[e[:path]] ||= { actions: {} }
              endpoints[e[:path]][:actions].merge!(actions)
            end
          end
        end
      end
    end

    def context_for(path, action)
      JsonapiCompliable.config.context_for_endpoint.call(path, action)
    end

    def generate_resources
      @resources.map do |r|
        config = {
          name: r.name,
          type: r.type,
          attributes: attributes(r),
          extra_attributes: extra_attributes(r),
          filters: filters(r),
          relationships: relationships(r)
        }

        if r.polymorphic?
          config.merge!(polymorphic: true, children: r.children.map(&:name))
        end

        config
      end
    end

    def attributes(resource)
      {}.tap do |attrs|
        resource.attributes.each_pair do |name, config|
          if config.values_at(:readable, :writable, :sortable).any?
            attrs[name] = {
              type:       config[:type],
              readable:   flag(config[:readable]),
              writable:   flag(config[:writable]),
              sortable:   flag(config[:sortable])
            }
          end
        end
      end
    end

    def extra_attributes(resource)
      {}.tap do |attrs|
        resource.extra_attributes.each_pair do |name, config|
          attrs[name] = {
            type:     config[:type],
            readable: flag(config[:readable])
          }
        end
      end
    end

    def flag(value)value
      if value.is_a?(Symbol)
        :guarded
      else
        !!value
      end
    end

    def filters(resource)
      {}.tap do |f|
        resource.filters.each_pair do |name, config|
          config = {
            type: config[:type],
            operators: config[:operators].keys
          }
          attr = resource.attributes[name]
          config[:required] = true if attr[:filterable] == :required
          config[:guard] = true if attr[:filterable].is_a?(Symbol)
          f[name] = config
        end
      end
    end

    def relationships(resource)
      {}.tap do |r|
        resource.sideloads.each_pair do |name, config|
          schema = { type: config.type }
          if config.type == :polymorphic_belongs_to
            schema[:resources] = config.children.values
              .map(&:resource).map(&:class).map(&:name)
          else
            schema[:resource] = config.resource.class.name
          end

          r[name] = schema
        end
      end
    end
  end
end
