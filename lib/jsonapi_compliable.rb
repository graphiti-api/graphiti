require "jsonapi_compliable/version"
require "jsonapi_compliable/configuration"
require "jsonapi_compliable/errors"
require "jsonapi_compliable/resource"
require "jsonapi_compliable/query"
require "jsonapi_compliable/sideload"
require "jsonapi_compliable/scope"
require "jsonapi_compliable/deserializer"
require "jsonapi_compliable/scoping/base"
require "jsonapi_compliable/scoping/sort"
require "jsonapi_compliable/scoping/paginate"
require "jsonapi_compliable/scoping/extra_fields"
require "jsonapi_compliable/scoping/filterable"
require "jsonapi_compliable/scoping/default_filter"
require "jsonapi_compliable/scoping/filter"
require "jsonapi_compliable/util/render_options"
require "jsonapi_compliable/adapters/abstract"
require "jsonapi_compliable/stats/dsl"
require "jsonapi_compliable/stats/payload"
require "jsonapi_compliable/util/include_params"
require "jsonapi_compliable/util/field_params"
require "jsonapi_compliable/util/hash"
require "jsonapi_compliable/util/relationship_payload"
require "jsonapi_compliable/util/persistence"
require "jsonapi_compliable/util/validation_response"
require "jsonapi_compliable/util/sideload"
require "jsonapi_compliable/util/hooks"

# require correct jsonapi-rb before extensions
if defined?(Rails)
  require 'jsonapi_compliable/rails'
else
  require 'jsonapi/serializable'
end

# Temporary fix until fixed upstream
# https://github.com/jsonapi-rb/jsonapi-serializable/pull/102
JSONAPI::Serializable::Resource.class_eval do
  def requested_relationships(fields)
    @_relationships
  end
end

require "jsonapi_compliable/extensions/extra_attribute"
require "jsonapi_compliable/extensions/boolean_attribute"
require "jsonapi_compliable/extensions/temp_id"

module JsonapiCompliable
  autoload :Base, 'jsonapi_compliable/base'

  def self.included(klass)
    klass.instance_eval do
      include Base
    end
  end

  # @api private
  def self.context
    Thread.current[:context] ||= {}
  end

  # @api private
  def self.context=(val)
    Thread.current[:context] = val
  end

  # @api private
  def self.with_context(obj, namespace)
    begin
      prior = self.context
      self.context = { object: obj, namespace: namespace }
      yield
    ensure
      self.context = prior
    end
  end

  def self.config
    @config ||= Configuration.new
  end

  # @example
  #   JsonapiCompliable.configure do |c|
  #     c.raise_on_missing_sideload = false
  #   end
  #
  # @see Configuration
  def self.configure
    yield config
  end
end
