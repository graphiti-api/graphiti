require 'json'
require 'active_support/core_ext/string'
require 'active_support/core_ext/class/attribute'
require 'active_support/concern'
require 'active_support/time'

require 'dry-types'

require 'jsonapi/serializable'
# Temporary fix until fixed upstream
# https://github.com/jsonapi-rb/jsonapi-serializable/pull/102
JSONAPI::Serializable::Resource.class_eval do
  def requested_relationships(fields)
    @_relationships
  end
end

# This library looks up a serializer based on the record's class name
# This wouldn't work for us, since a model may be associated with
# multiple resources.
# Instead, this variable is assigned when the query is resolved
# To ensure we always render with the *resource* serializer
JSONAPI::Serializable::Renderer.class_eval do
  def _build(object, exposures, klass)
    klass = object.instance_variable_get(:@__serializer_klass)
    klass.new(exposures.merge(object: object))
  end
end

# See above comment
JSONAPI::Serializable::Relationship.class_eval do
  def data
    @_resources_block = proc do
      resources = yield
      if resources.nil?
        nil
      elsif resources.respond_to?(:to_ary)
        Array(resources).map do |obj|
          klass = obj.instance_variable_get(:@__serializer_klass)
          klass.new(@_exposures.merge(object: obj))
        end
      else
        klass = resources.instance_variable_get(:@__serializer_klass)
        klass.new(@_exposures.merge(object: resources))
      end
    end
  end
end

require "jsonapi_compliable/version"
require "jsonapi_compliable/configuration"
require "jsonapi_compliable/errors"
require "jsonapi_compliable/types"
require "jsonapi_compliable/adapters/abstract"
require "jsonapi_compliable/resource/sideloading"
require "jsonapi_compliable/resource/configuration"
require "jsonapi_compliable/resource/dsl"
require "jsonapi_compliable/resource/polymorphism"
require "jsonapi_compliable/sideload"
require "jsonapi_compliable/sideload/has_many"
require "jsonapi_compliable/sideload/belongs_to"
require "jsonapi_compliable/sideload/has_one"
require "jsonapi_compliable/sideload/many_to_many"
require "jsonapi_compliable/sideload/polymorphic_belongs_to"
require "jsonapi_compliable/resource"
require "jsonapi_compliable/resource_proxy"
require "jsonapi_compliable/single_resource_proxy"
require "jsonapi_compliable/query"
require "jsonapi_compliable/scope"
require "jsonapi_compliable/deserializer"
require "jsonapi_compliable/renderer"
require "jsonapi_compliable/scoping/base"
require "jsonapi_compliable/scoping/sort"
require "jsonapi_compliable/scoping/paginate"
require "jsonapi_compliable/scoping/extra_attributes"
require "jsonapi_compliable/scoping/filterable"
require "jsonapi_compliable/scoping/default_filter"
require "jsonapi_compliable/scoping/filter"
require "jsonapi_compliable/util/render_options"
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
require "jsonapi_compliable/util/attribute_check"
require "jsonapi_compliable/util/serializer_attributes"

require 'jsonapi_compliable/adapters/null'

require "jsonapi_compliable/extensions/extra_attribute"
require "jsonapi_compliable/extensions/boolean_attribute"
require "jsonapi_compliable/extensions/temp_id"

if defined?(ActiveRecord)
  require 'jsonapi_compliable/adapters/active_record'
end

if defined?(Rails)
  require 'jsonapi_compliable/railtie'
end

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
  def self.with_context(obj, namespace = nil)
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

require "jsonapi_compliable/runner"
