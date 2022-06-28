require "json"
require "forwardable"
require "uri"
require "active_support/core_ext/string"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/class/attribute"
require "active_support/core_ext/hash/conversions" # to_xml
require "active_support/concern"
require "active_support/time"
require "active_support/deprecation"

require "dry-types"
require "graphiti_errors"

require "jsonapi/serializable"

module Graphiti
  DEPRECATOR = ActiveSupport::Deprecation.new("2.0", "Graphiti")

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
    prior = context
    self.context = {object: obj, namespace: namespace}
    yield
  ensure
    self.context = prior

    resources.each do |resource_class|
      resource_class.sideloads.values.each(&:clear_resources)
    end
  end

  def self.config
    @config ||= Configuration.new
  end

  # @example
  #   Graphiti.configure do |c|
  #     c.raise_on_missing_sideload = false
  #   end
  #
  # @see Configuration
  def self.configure
    yield config
  end

  def self.resources
    @resources ||= []
  end

  def self.broadcast(name, payload)
    # AS::N prefers domain naming format with more specific towards end
    name = "#{name}.graphiti"

    ActiveSupport::Notifications.instrument(name, payload) do
      yield payload if block_given?
    end
  end

  def self.logger
    @logger ||= stdout_logger
  end

  def self.stdout_logger
    logger = Logger.new($stdout)
    logger.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end
    logger
  end

  def self.logger=(val)
    @logger = val
  end

  def self.log(msg, color = :white, bold = false)
    colored = if ::ActiveSupport.version >= Gem::Version.new("7.1")
      ActiveSupport::LogSubscriber.new.send(:color, msg, color, bold: bold)
    else
      ActiveSupport::LogSubscriber.new.send(:color, msg, color, bold)
    end

    logger.debug(colored)
  end

  # When we add a sideload, we need to do configuration, such as
  # adding the relationship to the Resource's serializer.
  # However, the sideload's Resource class may not be loaded yet.
  #
  # This is not a problem when Rails autoloading, but is a problem
  # when *eager* loading, or not using Rails.
  #
  # So, load every Resource class then call Graphiti.setup!
  def self.setup!
    resources.each do |r|
      r.apply_sideloads_to_serializer
    end
  end

  def self.cache(name, kwargs = {}, &block)
    ::Rails.cache.fetch(name, **kwargs) do
      block.call
    end
  end
end

require "graphiti/version"
require "graphiti/jsonapi_serializable_ext"
require "graphiti/configuration"
require "graphiti/context"
require "graphiti/errors"
require "graphiti/types"
require "graphiti/schema"
require "graphiti/schema_diff"
require "graphiti/adapters/abstract"
require "graphiti/resource/sideloading"
require "graphiti/resource/links"
require "graphiti/resource/configuration"
require "graphiti/resource/dsl"
require "graphiti/resource/interface"
require "graphiti/resource/polymorphism"
require "graphiti/resource/documentation"
require "graphiti/resource/persistence"
require "graphiti/resource/remote"
require "graphiti/sideload"
require "graphiti/sideload/has_many"
require "graphiti/sideload/belongs_to"
require "graphiti/sideload/has_one"
require "graphiti/sideload/many_to_many"
require "graphiti/sideload/polymorphic_belongs_to"
require "graphiti/resource"
require "graphiti/resource_proxy"
require "graphiti/request_validator"
require "graphiti/request_validators/validator"
require "graphiti/request_validators/update_validator"
require "graphiti/scope"
require "graphiti/deserializer"
require "graphiti/renderer"
require "graphiti/hash_renderer"
require "graphiti/filter_operators"
require "graphiti/scoping/base"
require "graphiti/scoping/sort"
require "graphiti/scoping/paginate"
require "graphiti/scoping/extra_attributes"
require "graphiti/scoping/filterable"
require "graphiti/scoping/filter_group_validator"
require "graphiti/scoping/default_filter"
require "graphiti/scoping/filter"
require "graphiti/stats/dsl"
require "graphiti/stats/payload"
require "graphiti/delegates/pagination"
require "graphiti/util/include_params"
require "graphiti/util/field_params"
require "graphiti/util/hash"
require "graphiti/util/relationship_payload"
require "graphiti/util/persistence"
require "graphiti/util/validation_response"
require "graphiti/util/sideload"
require "graphiti/util/simple_errors"
require "graphiti/util/transaction_hooks_recorder"
require "graphiti/util/attribute_check"
require "graphiti/util/serializer_attributes"
require "graphiti/util/serializer_relationships"
require "graphiti/util/class"
require "graphiti/util/link"
require "graphiti/util/remote_serializer"
require "graphiti/util/remote_params"
require "graphiti/adapters/null"
require "graphiti/adapters/graphiti_api"
require "graphiti/extensions/extra_attribute"
require "graphiti/extensions/boolean_attribute"
require "graphiti/extensions/temp_id"
require "graphiti/serializer"
require "graphiti/query"
require "graphiti/debugger"

if defined?(ActiveRecord)
  require "graphiti/adapters/active_record"
end

if defined?(Rails)
  require "graphiti/rails"
  require "graphiti/responders"

  # graphiti-rails has own Railtie
  begin
    require "graphiti-rails"
  rescue LoadError
    require "graphiti/railtie"
  end
end

require "graphiti/runner"

# Because we set 2 magic variables when processing the graph,
# as_json will fail on a PORO with stack level too deep
#
# #as_json calls #instance_variables, defined in
# active_support/core_ext/object/instance_variables.rb
#
# So, override that to not see these magic vars.
module InstanceVariableOverride
  def instance_values
    values = super
    if @__graphiti_serializer
      values.reject! do |v|
        ["__graphiti_serializer", "__graphiti_resource"].include?(v)
      end
    end
    values
  end
end

class Object
  prepend InstanceVariableOverride
end

ActiveSupport.run_load_hooks(:graphiti, Graphiti)
