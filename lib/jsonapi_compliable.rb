require 'active_model_serializers'
require 'jsonapi'
require 'jsonapi_ams_extensions'

require "jsonapi_compliable/version"
require "jsonapi_compliable/errors"
require "jsonapi_compliable/dsl"

module JSONAPICompliable
  autoload :Base,           'jsonapi_compliable/base'
  autoload :Deserializable, 'jsonapi_compliable/deserializable'

  def self.included(klass)
    klass.instance_eval do
      include Base
      include Deserializable
    end
  end
end
