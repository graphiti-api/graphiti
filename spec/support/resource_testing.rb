RSpec.shared_context 'resource testing' do |parameter|
  let(:resource)     { described_class.new }
  let(:params)       { {} }
  let(:query)        { JsonapiCompliable::Query.new(resource, params) }
  let(:base_scope)   { double('please define base_scope in your test') }
  let(:scope)        { resource.build_scope(base_scope, query) }

  def render
    records = scope.resolve
    opts = params
    opts[:expose] = { context: resource.context }
    opts = JsonapiCompliable::Util::RenderOptions
      .generate(records, query.to_hash[resource.class.config[:type]], opts)
    resolved = opts.delete(:jsonapi)
    before_render
    raw_json = JSONAPI::Serializable::Renderer.new.render(resolved, opts).to_json
    response.body = raw_json
    JSON.parse(raw_json)
  end

  # override
  def before_render
  end

  def response
    @response ||= OpenStruct.new
  end
end
