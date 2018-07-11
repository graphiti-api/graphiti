module JsonapiCompliable
  class PersistenceProxy
    # Todo quack like same proxy (data, [], etc)
    # Ideally could return unpersisted graph, then save
    # then returns persisted graph

    # Todo: eventually this will have @query as well, to support
    # a POST to /posts?include=comments
    attr_reader :resource, :payload

    # ...todo scope?
    def initialize(resource, payload)
      @resource = resource
      @payload = payload
    end

    # jsonapi_create
    def save
      persist do
        @data = @resource.persist_with_relationships \
          @payload.meta,
          @payload.attributes,
          @payload.relationships
      end.to_a[1]
    end

    def jsonapi_render_options(opts = {})
      opts[:meta]   ||= {}
      opts[:expose] ||= {}
      opts[:expose][:context] = JsonapiCompliable.context[:object]
      opts
    end

    def to_jsonapi(options = {})
      options = jsonapi_render_options(options)
      Renderer.new(self, options).to_jsonapi
    end

    def update_attributes
      save
    end

    def destroy
      @resource.transaction do
        model = @resource.destroy(@payload.params[:filter][:id])
        model.instance_variable_set(:@__serializer_klass, @resource.serializer)
        @data = model
        validator = ::JsonapiCompliable::Util::ValidationResponse.new \
          model, @payload
        validator.validate!
        @resource.before_commit(model, :destroy)
        validator
      end.to_a[1]
    end

    def errors
      data.errors
    end

    def data
      @data
    end

    # TODO
    def stats
      {}
    end

    def persist
      @resource.transaction do
        ::JsonapiCompliable::Util::Hooks.record do
          model = yield
          validator = ::JsonapiCompliable::Util::ValidationResponse.new \
            model, @payload
          validator.validate!
          validator
        end
      end
    end
  end
end
