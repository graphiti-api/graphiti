RSpec.shared_context 'scoping' do
  let(:resource_class) do
    Class.new(JsonapiCompliable::Resource) do
      type :authors
      use_adapter JsonapiCompliable::Adapters::ActiveRecord
    end
  end

  let(:resource) { resource_class.new }
  let(:params)   { {} }
  let(:query)    { JsonapiCompliable::Query.new(resource, params) }

  let(:scope_object) { Author.all }
  let(:scope)        { resource.build_scope(scope_object, query) }

  def render(object, opts = {})
    opts[:expose] = { context: resource.context }
    opts = JsonapiCompliable::Util::RenderOptions.generate(object, query.to_hash[:authors], opts)
    resolved = opts.delete(:jsonapi)
    raw_json = JSONAPI::Serializable::Renderer.new.render(resolved, opts).to_json
    JSON.parse(raw_json)
  end
end
