RSpec.shared_context 'resource testing' do |parameter|
  let(:resource)     { described_class.new }
  let(:params)       { {} }

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
    json = proxy.to_jsonapi(runtime_options)
    response.body = json
    json
  end

  def proxy
    @proxy ||= begin
      ctx = TestRunner.new(resource, params)
      defined?(base_scope) ? ctx.proxy(base_scope) : ctx.proxy
    end
  end

  def records
    proxy.data
  end

  def response
    @response ||= OpenStruct.new
  end
end
