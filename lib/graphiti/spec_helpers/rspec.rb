require "rspec/core"
require "graphiti/spec_helpers"

module Graphiti
  module SpecHelpers
    class ContextProxy < OpenStruct
      def initialize(proxied, *args)
        @__proxied = proxied
        super(*args)
      end

      # variables defined in the rspec context should remain lazy
      def current_user
        super || __proxied_current_user
      end

      def params
        super || __proxied_params
      end

      private

      def __proxied_current_user
        @__proxied.current_user if @__proxied.respond_to?(:current_user)
      end

      def __proxied_params
        @__proxied.params if @__proxied.respond_to?(:params)
      end
    end
  end
end

# Registered under both names. The graphiti-prefixed name is canonical. The bare
# one is kept for suites that include it explicitly, and carries no `type:`
# metadata so a `type: :resource` group does not pick the context up twice.
resource_testing = proc do
  let(:resource) { described_class }
  let(:params) { {} }

  around do |e|
    original = Graphiti::Resource.validate_endpoints
    Graphiti::Resource.validate_endpoints = false

    Graphiti.with_context graphiti_context do
      e.run
    end
  ensure
    Graphiti::Resource.validate_endpoints = original
  end

  def graphiti_context
    @graphiti_context ||= Graphiti::SpecHelpers::ContextProxy.new(self)
  end

  # If you need to set context:
  #
  # Graphiti.with_context my_context, {} do
  #   render
  # end
  def render(runtime_options = {})
    json = proxy.to_jsonapi(runtime_options)
    response.body = json
    json
  end

  def proxy
    @proxy ||= begin
      args = [params]
      args << base_scope if defined?(base_scope)
      resource.all(*args)
    end
  end

  def records
    proxy.data
  end

  def response
    @response ||= OpenStruct.new
  end
end

remote_api = proc do
  # Fake request headers
  around do |e|
    ctx = OpenStruct.new \
      request: OpenStruct.new(headers: OpenStruct.new)
    Graphiti.with_context(ctx) { e.run }
  end

  def mock_api(url, json, call_count = 1)
    api_response = double(body: json.to_json)
    expect(Faraday).to receive(:get)
      .with(url, anything, anything)
      .exactly(call_count).times
      .and_return(api_response)
  end
end

# Was a top-level constant, and reopening it to add context methods was a way
# suites customised graphiti_context. Remove in 3.0.
GraphitiContextProxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(
  "GraphitiContextProxy",
  "Graphiti::SpecHelpers::ContextProxy",
  Graphiti::DEPRECATOR
)

::RSpec.shared_context("graphiti resource testing", type: :resource, &resource_testing)
::RSpec.shared_context("resource testing", &resource_testing)

::RSpec.shared_context("graphiti remote api", &remote_api)
::RSpec.shared_context("remote api", &remote_api)

module Graphiti
  module SpecHelpers
    module RSpec
      def self.included(klass)
        klass.send(:include, Graphiti::SpecHelpers)

        ::RSpec.configure do |rspec|
          rspec.include_context "graphiti resource testing", type: :resource
          rspec.include Graphiti::SpecHelpers::Matchers, type: :resource
        end
      end

      def self.schema!(resources = nil)
        ::RSpec.describe "Graphiti Schema" do
          it "generates a backwards-compatible schema" do
            message = <<~MSG
              Found backwards-incompatibilities in schema! Run with FORCE_SCHEMA=true to ignore.

              Incompatibilities:

            MSG

            errors = Graphiti::Schema.generate!(resources)
            errors.each do |e|
              message << "#{e}\n"
            end

            expect(errors.empty?).to eq(true), message
          end
        end
      end
    end
  end
end
