module JsonapiCompliable
  class SingleResourceProxy < ResourceProxy
    def data
      record = to_a[0]
      raise JsonapiCompliable::Errors::RecordNotFound unless record
      record
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

    def record
      data
    end
  end
end
