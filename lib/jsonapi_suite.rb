require 'active_model_serializers'
require 'strong_resources'
require 'jsonapi_compliable'
require 'jsonapi_errorable'
require 'jsonapi_ams_extensions'
require 'jsonapi_swagger_helpers'
require 'nested_attribute_reassignable'

if ENV['RAILS_ENV'] == 'test'
  require 'rspec-rails'
  require 'jsonapi_spec_helpers'
end

require "jsonapi_suite/version"

module JsonapiSuite
end
