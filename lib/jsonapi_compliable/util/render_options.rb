module JsonapiCompliable
  module Util
    # Generate the options we end up passing to {{http://jsonapi-rb.org jsonapi-rb}}
    # @api private
    class RenderOptions
      def self.generate(overrides = {})





        options            = {}
        options[:include]  = query.include_hash
        options[:fields]   = fields
        options.merge!(overrides)
        options[:meta]   ||= {}
        options[:expose] ||= {}
        options[:expose][:extra_fields] = extra_fields
        options
      end
    end
  end
end
