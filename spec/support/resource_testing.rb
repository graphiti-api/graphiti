RSpec.shared_context 'resource testing' do |parameter|
  let(:resource)     { described_class.new }
  let(:params)       { {} }
  let(:base_scope)   { double('please define base_scope in your test') }

  class TestRunner < JsonapiCompliable::Runner
    def current_user
      nil
    end
  end

  # If you need to set context:
  #
  # JsonapiCompliable.with_context my_context, {} do
  #   render
  # end
  def render(runtime_options = {})
    ctx = TestRunner.new(resource, params)
    records, meta = ctx.resolve(base_scope)
    runtime_options[:meta] ||= {}
    runtime_options[:meta].merge!(meta)
    json = ctx.render_jsonapi(records, runtime_options)
    response.body = json
    json
  end

  def records
    ctx = TestRunner.new(resource, params)
    ctx.resolve(base_scope)[0]
  end

  def response
    @response ||= OpenStruct.new
  end
end
