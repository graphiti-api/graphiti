RSpec.shared_context 'resource testing' do |parameter|
  let(:resource)     { described_class.new }
  let(:params)       { {} }
  let(:query)        { JsonapiCompliable::Query.new(resource, params) }
  let(:base_scope)   { double('please define base_scope in your test') }
  let(:scope)        { resource.build_scope(base_scope, query) }

  # TODO: Need to dedup this with render_jsonapi
  def render(runtime_options = {})
    records = scope.resolve
    stats = scope.resolve_stats
    opts = params
    opts = JsonapiCompliable::Util::RenderOptions
      .generate(records, query.to_hash[resource.class.config[:type]])
    opts[:expose].merge!(context: resource.context)
    resolved = opts.delete(:jsonapi)
    before_render
    opts.merge!(runtime_options)

    if stats && !stats.empty?
      opts[:meta].merge!(stats: stats)
    end

    raw_json = JSONAPI::Serializable::Renderer.new
      .render(resolved, opts).to_json
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
