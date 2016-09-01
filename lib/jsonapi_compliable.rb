require "jsonapi_compliable/version"

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
